import SwiftData
import XCTest
@testable import IsoMe

/// Tests for `VisitQuery` / `MovementQuery` fetch helpers and entity name
/// fallbacks. All fetches run against a throwaway in-memory container — the
/// on-disk store is never touched.
@MainActor
final class IsoMeEntityQueryTests: XCTestCase {
    // MARK: - Fixtures

    /// Mirrors `IntentSupport`'s schema, in memory only.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Visit.self,
            LocationPoint.self,
            RecordingSession.self,
            PhotoMoment.self,
            SavedPlace.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func insertVisits(arrivedAtDates: [Date], into context: ModelContext) throws -> [Visit] {
        let visits = arrivedAtDates.map { date in
            Visit(latitude: 37.7749, longitude: -122.4194, arrivedAt: date)
        }
        visits.forEach(context.insert)
        try context.save()
        return visits
    }

    private func insertSessions(startedAtDates: [Date], into context: ModelContext) throws -> [RecordingSession] {
        let sessions = startedAtDates.map { date in
            RecordingSession(startedAt: date)
        }
        sessions.forEach(context.insert)
        try context.save()
        return sessions
    }

    // MARK: - suggestedEntities: recency ordering + limit

    func testVisitFetchRecentOrdersByArrivedAtDescendingAndLimits() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try insertVisits(
            arrivedAtDates: (0..<25).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let entities = try VisitQuery.fetchRecent(context: context, limit: 20)

        XCTAssertEqual(entities.count, 20)
        let timestamps = entities.map(\.arrivedAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >), "expected newest-first ordering")
        XCTAssertEqual(timestamps.first, base.addingTimeInterval(24 * 3600), "expected the newest visit first")
    }

    func testMovementFetchRecentOrdersByStartedAtDescendingAndLimits() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try insertSessions(
            startedAtDates: (0..<25).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let entities = try MovementQuery.fetchRecent(context: context, limit: 20)

        XCTAssertEqual(entities.count, 20)
        let timestamps = entities.map(\.startedAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >), "expected newest-first ordering")
        XCTAssertEqual(timestamps.first, base.addingTimeInterval(24 * 3600), "expected the newest session first")
    }

    // MARK: - entities(for:) resolution

    func testVisitFetchByIdentifiersResolvesSubset() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let visits = try insertVisits(
            arrivedAtDates: [base, base.addingTimeInterval(60), base.addingTimeInterval(120)],
            into: context
        )

        let wanted: Set<UUID> = [visits[0].id, visits[2].id]
        let entities = try VisitQuery.fetch(context: context, identifiers: Array(wanted))

        XCTAssertEqual(Set(entities.map(\.id)), wanted)
        XCTAssertEqual(entities.count, 2)
    }

    func testMovementFetchByIdentifiersResolvesSubset() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = try insertSessions(
            startedAtDates: [base, base.addingTimeInterval(60), base.addingTimeInterval(120)],
            into: context
        )

        let wanted: Set<UUID> = [sessions[0].id, sessions[2].id]
        let entities = try MovementQuery.fetch(context: context, identifiers: Array(wanted))

        XCTAssertEqual(Set(entities.map(\.id)), wanted)
        XCTAssertEqual(entities.count, 2)
    }

    // MARK: - Name fallback chains

    func testVisitEntityNameFallbackChain() {
        XCTAssertEqual(VisitEntity.displayName(customName: " Gym ", locationName: nil, address: nil), "Gym")
        XCTAssertEqual(
            VisitEntity.displayName(customName: "   ", locationName: "Blue Bottle", address: "123 Main St"),
            "Blue Bottle",
            "whitespace-only customName should be skipped"
        )
        XCTAssertEqual(
            VisitEntity.displayName(customName: nil, locationName: nil, address: "123 Main St"),
            "123 Main St"
        )
        XCTAssertEqual(
            VisitEntity.displayName(customName: nil, locationName: nil, address: "   "),
            "Visit",
            "whitespace-only address should fall through to the last resort"
        )
    }

    func testMovementEntityNameFallbackChain() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(MovementEntity.displayName(customName: " Morning Run ", startedAt: startedAt), "Morning Run")

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .none
        XCTAssertEqual(
            MovementEntity.displayName(customName: "\t\n ", startedAt: startedAt),
            expectedFormatter.string(from: startedAt),
            "whitespace-only customName should fall back to the medium-style start date"
        )
        XCTAssertEqual(
            MovementEntity.displayName(customName: nil, startedAt: startedAt),
            expectedFormatter.string(from: startedAt)
        )
    }

    // MARK: - Date-window helpers (for the cycle-2 date-range conformance)

    func testVisitFetchArrivedWithinFiltersToWindow() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-10 * 86400),
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-0.5 * 86400),
            ],
            into: context
        )

        let window = base.addingTimeInterval(-7 * 86400)...base
        let entities = try VisitQuery.fetch(context: context, arrivedWithin: window)

        XCTAssertEqual(Set(entities.map(\.id)), Set([inserted[1].id, inserted[2].id]))
        XCTAssertEqual(entities.map(\.id), [inserted[2].id, inserted[1].id], "expected newest-first ordering")
    }

    func testMovementFetchStartedWithinFiltersToWindow() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertSessions(
            startedAtDates: [
                base.addingTimeInterval(-10 * 86400),
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-0.5 * 86400),
            ],
            into: context
        )

        let window = base.addingTimeInterval(-7 * 86400)...base
        let entities = try MovementQuery.fetch(context: context, startedWithin: window)

        XCTAssertEqual(Set(entities.map(\.id)), Set([inserted[1].id, inserted[2].id]))
        XCTAssertEqual(entities.map(\.id), [inserted[2].id, inserted[1].id], "expected newest-first ordering")
    }

    // MARK: - Empty store

    func testEmptyStoreReturnsEmptyResultsWithoutCrashing() throws {
        let context = try makeContext()

        XCTAssertEqual(try VisitQuery.fetchRecent(context: context, limit: 20).count, 0)
        XCTAssertEqual(try MovementQuery.fetchRecent(context: context, limit: 20).count, 0)
        XCTAssertEqual(try VisitQuery.fetch(context: context, identifiers: [UUID()]).count, 0)
        XCTAssertEqual(try MovementQuery.fetch(context: context, identifiers: [UUID()]).count, 0)
        XCTAssertEqual(try VisitQuery.fetch(context: context, arrivedWithin: Date.distantPast...Date.distantFuture).count, 0)
        XCTAssertEqual(try MovementQuery.fetch(context: context, startedWithin: Date.distantPast...Date.distantFuture).count, 0)
    }
}
