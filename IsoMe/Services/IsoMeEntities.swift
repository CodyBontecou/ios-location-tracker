import AppIntents
import Foundation
import SwiftData

// MARK: - VisitEntity

/// App entity snapshot of a Visit (`IsoMe/Models/Visit.swift`).
///
/// AppEntities cross process boundaries (Shortcuts pickers, Siri resolution),
/// so the entity snapshots display fields as plain values rather than holding
/// the SwiftData `@Model` instance alive.
struct VisitEntity: AppEntity {
    let id: UUID
    let customName: String?
    let locationName: String?
    let address: String?
    let arrivedAt: Date

    /// Fallback chain mirrors `Visit.normalizedCustomName` guarding plus
    /// `Visit.automaticDisplayName`: trimmed customName → locationName →
    /// address → "Visit".
    var name: String {
        Self.displayName(customName: customName, locationName: locationName, address: address)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Visit"
    static var defaultQuery = VisitQuery()

    init(
        id: UUID,
        customName: String?,
        locationName: String?,
        address: String?,
        arrivedAt: Date
    ) {
        self.id = id
        self.customName = customName
        self.locationName = locationName
        self.address = address
        self.arrivedAt = arrivedAt
    }

    init(visit: Visit) {
        self.init(
            id: visit.id,
            customName: visit.customName,
            locationName: visit.locationName,
            address: visit.address,
            arrivedAt: visit.arrivedAt
        )
    }

    static func displayName(customName: String?, locationName: String?, address: String?) -> String {
        normalized(customName) ?? normalized(locationName) ?? normalized(address) ?? "Visit"
    }

    /// Same trim/nil guarding as `Visit.normalizedCustomName` in
    /// `IsoMe/Models/RecordingSession.swift`'s sibling models.
    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

// MARK: - MovementEntity

/// App entity snapshot of a RecordingSession (`IsoMe/Models/RecordingSession.swift`).
/// The app UI calls these "Movements" / outings.
struct MovementEntity: AppEntity {
    let id: UUID
    let customName: String?
    let startedAt: Date
    let endedAt: Date?

    var name: String {
        Self.displayName(customName: customName, startedAt: startedAt)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Movement"
    static var defaultQuery = MovementQuery()

    init(
        id: UUID,
        customName: String?,
        startedAt: Date,
        endedAt: Date?
    ) {
        self.id = id
        self.customName = customName
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    init(session: RecordingSession) {
        self.init(
            id: session.id,
            customName: session.customName,
            startedAt: session.startedAt,
            endedAt: session.endedAt
        )
    }

    static func displayName(customName: String?, startedAt: Date) -> String {
        if let custom = normalized(customName) {
            return custom
        }
        // The UI's full default title ("Outing N" via
        // `RecordingSessionSummary.defaultTitle`) requires sequencing every
        // session in the store; that math is too heavy for an entity title, so
        // unnamed movements fall back to their medium-style start date.
        return dateFallbackFormatter.string(from: startedAt)
    }

    private static let dateFallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

// MARK: - VisitQuery

/// Query backing VisitEntity pickers in Shortcuts. Reads go through
/// `IntentSupport.modelContainer` / `makeContext()`, the same on-disk store
/// the existing intents use.
struct VisitQuery: EntityQuery {
    /// How many recent visits to offer in pickers.
    static let suggestedEntitiesLimit = 20

    @MainActor
    func suggestedEntities() async throws -> [VisitEntity] {
        try Self.fetchRecent(context: IntentSupport.makeContext(), limit: Self.suggestedEntitiesLimit)
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [VisitEntity] {
        try Self.fetch(context: IntentSupport.makeContext(), identifiers: identifiers)
    }

    // MARK: Fetch helpers
    // Context is injected so tests run against an in-memory store instead of
    // the on-disk one; the `perform`-adjacent glue above stays thin.

    /// Most recent visits, newest first (recency for pickers — the export
    /// conventions in `ExportRunner` sort ascending only when feeding files).
    @MainActor
    static func fetchRecent(context: ModelContext, limit: Int) throws -> [VisitEntity] {
        var descriptor = FetchDescriptor<Visit>()
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map(VisitEntity.init(visit:))
    }

    /// Resolve by id, newest first.
    @MainActor
    static func fetch(context: ModelContext, identifiers: [UUID]) throws -> [VisitEntity] {
        guard !identifiers.isEmpty else { return [] }
        var descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { visit in identifiers.contains(visit.id) }
        )
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]
        return try context.fetch(descriptor).map(VisitEntity.init(visit:))
    }

    /// Date-windowed visits (e.g. "visits from last week"), newest first.
    // TODO(cycle-2): surface date-windowed suggestions to Shortcuts. There is
    // no `EntityDateRangeQuery` in the AppIntents SDK (verified against the
    // iPhoneSimulator swiftinterface); the real date-filtering surface is
    // `EntityPropertyQuery` comparator plumbing, which is heavyweight for this
    // cycle. The fetch below is ready and unit-tested — next cycle can wire it
    // into an intent parameter or a property-query conformance.
    @MainActor
    static func fetch(context: ModelContext, arrivedWithin range: ClosedRange<Date>) throws -> [VisitEntity] {
        var descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { visit in
                visit.arrivedAt >= range.lowerBound && visit.arrivedAt <= range.upperBound
            }
        )
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]
        return try context.fetch(descriptor).map(VisitEntity.init(visit:))
    }
}

// MARK: - MovementQuery

/// Query backing MovementEntity pickers in Shortcuts. Reads go through
/// `IntentSupport.modelContainer` / `makeContext()`, the same on-disk store
/// the existing intents use.
struct MovementQuery: EntityQuery {
    /// How many recent movements to offer in pickers.
    static let suggestedEntitiesLimit = 20

    @MainActor
    func suggestedEntities() async throws -> [MovementEntity] {
        try Self.fetchRecent(context: IntentSupport.makeContext(), limit: Self.suggestedEntitiesLimit)
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [MovementEntity] {
        try Self.fetch(context: IntentSupport.makeContext(), identifiers: identifiers)
    }

    // MARK: Fetch helpers
    // Context is injected so tests run against an in-memory store instead of
    // the on-disk one; the `perform`-adjacent glue above stays thin.

    /// Most recent movements, newest first (recency for pickers — the export
    /// conventions in `ExportRunner` sort ascending only when feeding files).
    @MainActor
    static func fetchRecent(context: ModelContext, limit: Int) throws -> [MovementEntity] {
        var descriptor = FetchDescriptor<RecordingSession>()
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map(MovementEntity.init(session:))
    }

    /// Resolve by id, newest first.
    @MainActor
    static func fetch(context: ModelContext, identifiers: [UUID]) throws -> [MovementEntity] {
        guard !identifiers.isEmpty else { return [] }
        var descriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { session in identifiers.contains(session.id) }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        return try context.fetch(descriptor).map(MovementEntity.init(session:))
    }

    /// Date-windowed movements (e.g. "outings from last week"), newest first.
    // TODO(cycle-2): see VisitQuery.fetch(context:arrivedWithin:) — the
    // conformance glue for date-windowed suggestions is deferred; this fetch
    // is ready and unit-tested.
    @MainActor
    static func fetch(context: ModelContext, startedWithin range: ClosedRange<Date>) throws -> [MovementEntity] {
        var descriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { session in
                session.startedAt >= range.lowerBound && session.startedAt <= range.upperBound
            }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        return try context.fetch(descriptor).map(MovementEntity.init(session:))
    }
}
