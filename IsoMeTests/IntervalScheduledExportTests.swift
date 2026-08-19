import XCTest
import ExportKit
@testable import IsoMe

final class IntervalScheduledExportTests: XCTestCase {
    // MARK: - Interval occurrence math

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testMaxStepIndexCoversThe24HourCycle() {
        // anchor + k×interval strictly below 24h
        XCTAssertEqual(IntervalExportScheduleDateMath.maxStepIndex(intervalHours: 3), 7)   // 09,12,…,06(+21h)
        XCTAssertEqual(IntervalExportScheduleDateMath.maxStepIndex(intervalHours: 12), 1)
        XCTAssertEqual(IntervalExportScheduleDateMath.maxStepIndex(intervalHours: 9), 2)   // 0,9,18
        XCTAssertEqual(IntervalExportScheduleDateMath.maxStepIndex(intervalHours: 23), 1)  // 0,23
        XCTAssertEqual(IntervalExportScheduleDateMath.maxStepIndex(intervalHours: 1), 23)
    }

    func testClampPreservesOnceDaily() {
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(0), 0)
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(-5), 0)
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(1), 1)
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(23), 23)
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(24), 23)
        XCTAssertEqual(IntervalExportScheduleDateMath.clampIntervalHours(99), 23)
    }

    func testNextOccurrenceWalksThreeHourSlots() {
        let cal = calendar
        // Anchor 09:00, every 3h → 09,12,15,18,21,00,03,06 (into the next day), then a new anchor.
        let cases: [(String, String)] = [
            ("2026-05-04T13:00:00-07:00", "2026-05-04T15:00:00-07:00"), // 13:00 → 15:00
            ("2026-05-04T16:30:00-07:00", "2026-05-04T18:00:00-07:00"), // 16:30 → 18:00
            ("2026-05-04T20:30:00-07:00", "2026-05-04T21:00:00-07:00"), // 20:30 → 21:00
            ("2026-05-05T04:30:00-07:00", "2026-05-05T06:00:00-07:00"), // 04:30 → 06:00 (yesterday's cycle tail)
            ("2026-05-05T13:30:00-07:00", "2026-05-05T15:00:00-07:00"), // 13:30 → 15:00 (new cycle)
        ]
        for (nowISO, expectedISO) in cases {
            let next = IntervalExportScheduleDateMath.nextOccurrence(
                anchorHour: 9, anchorMinute: 0, intervalHours: 3,
                after: date(nowISO), calendar: cal
            )
            XCTAssertEqual(next, date(expectedISO), "now \(nowISO)")
        }
    }

    func testLatestOccurrenceIncludesCycleTailPastMidnight() {
        let cal = calendar
        // 09:00 anchor every 3h; at 01:00 the latest occurrence is yesterday cycle's 00:00 slot.
        let latest = IntervalExportScheduleDateMath.latestOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 3,
            at: date("2026-05-05T01:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(latest, date("2026-05-05T00:00:00-07:00"))
    }

    func testLatestOccurrenceAtExactFireTimeCountsAsDue() {
        let cal = calendar
        let latest = IntervalExportScheduleDateMath.latestOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 3,
            at: date("2026-05-04T12:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(latest, date("2026-05-04T12:00:00-07:00"))

        let next = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 3,
            after: date("2026-05-04T12:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(next, date("2026-05-04T15:00:00-07:00"))
    }

    func testNineHourIntervalSpillsPastMidnightThenResets() {
        let cal = calendar
        // 09:00 anchor every 9h → 09:00, 18:00, 03:00(+18h, next day).
        let next = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 9,
            after: date("2026-05-04T21:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(next, date("2026-05-05T03:00:00-07:00"))

        // After the 03:00 slot, the next fire is the next day's 09:00 anchor.
        let reset = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 9,
            after: date("2026-05-05T03:30:00-07:00"), calendar: cal
        )
        XCTAssertEqual(reset, date("2026-05-05T09:00:00-07:00"))
    }

    func testTwentyThreeHourIntervalHasTwoFiresPerCycle() {
        let cal = calendar
        // 09:00 anchor every 23h → 09:00 day 1, 08:00 day 2, then reset at day 2's 09:00.
        let next = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 23,
            after: date("2026-05-04T09:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(next, date("2026-05-05T08:00:00-07:00"))

        let reset = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 23,
            after: date("2026-05-05T08:00:00-07:00"), calendar: cal
        )
        XCTAssertEqual(reset, date("2026-05-05T09:00:00-07:00"))
    }

    func testDSTSpringForwardKeepsWallClockAnchor() {
        let cal = calendar
        // US DST starts 2026-03-08 02:00 PT. The 09:00 anchor on Mar 8 is PDT (UTC-7).
        let before = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 12,
            after: date("2026-03-08T01:30:00-08:00"), calendar: cal
        )
        XCTAssertEqual(before, local(2026, 3, 8, 9))

        let after = IntervalExportScheduleDateMath.nextOccurrence(
            anchorHour: 9, anchorMinute: 0, intervalHours: 12,
            after: date("2026-03-09T10:30:00-07:00"), calendar: cal
        )
        XCTAssertEqual(after, local(2026, 3, 9, 21))
    }

    // MARK: - Day-stable filename patterns

    func testDayStablePatternReplacesUnstableTimeTokens() {
        XCTAssertEqual(
            FilenameTemplate.dayStablePattern(from: "isome_{type}_{datetime}"),
            "isome_{type}_{date}"
        )
        XCTAssertEqual(
            FilenameTemplate.dayStablePattern(from: "track-{time}"),
            "track-{date}"
        )
    }

    func testDayStablePatternInjectsDateTokenWhenMissing() {
        XCTAssertEqual(
            FilenameTemplate.dayStablePattern(from: "isome_{type}_{format}.csv"),
            "isome_{type}_{format} - {date}.csv"
        )
        XCTAssertEqual(
            FilenameTemplate.dayStablePattern(from: "exports/track"),
            "exports/track - {date}"
        )
    }

    func testDayStablePatternLeavesDayStablePatternsAlone() {
        let pattern = "{year}/{year}-{month}/Daily Track - {date}"
        XCTAssertEqual(FilenameTemplate.dayStablePattern(from: pattern), pattern)
        let defaultPattern = "iso.me - {day} {date} - {type}"
        XCTAssertEqual(FilenameTemplate.dayStablePattern(from: defaultPattern), defaultPattern)
    }

    // MARK: - Write policy

    func testAppendPolicyForFormats() {
        for format in [ExportFormat.gpx, .kml] {
            let policy = IsoMeScheduledExportWritePolicy.resolve(format: format, fileMode: .append)
            XCTAssertEqual(policy.writeMode, .overwrite)
            XCTAssertFalse(policy.usesDeltaWindow)
            XCTAssertNil(policy.mergeStrategy)
        }

        for format in [ExportFormat.json, .csv, .markdown, .owntracks, .overland, .geojson] {
            let policy = IsoMeScheduledExportWritePolicy.resolve(format: format, fileMode: .append)
            XCTAssertEqual(policy.writeMode, .update)
            XCTAssertTrue(policy.usesDeltaWindow)
            XCTAssertNotNil(policy.mergeStrategy)
        }

        for format in ExportFormat.allCases {
            let policy = IsoMeScheduledExportWritePolicy.resolve(format: format, fileMode: .rewrite)
            XCTAssertEqual(policy.writeMode, .overwrite)
            XCTAssertNil(policy.mergeStrategy)
        }
    }

    // MARK: - Merge strategies

    private func plannedFile(content: String) -> PlannedExportFile {
        PlannedExportFile(
            id: "test-\(content.hashValue)",
            role: .aggregate(formatID: "csv"),
            relativePath: "test.csv",
            content: content,
            estimatedByteCount: content.utf8.count
        )
    }

    func testCSVAppendSkipsHeaderRow() throws {
        let strategy = CSVAppendMergeStrategy()
        let existing = "arrived_at,departed_at,latitude\n2026-05-04T09:00:00Z,,37.77\n"
        let incoming = "arrived_at,departed_at,latitude\n2026-05-04T12:00:00Z,,37.78\n"

        let merged = try strategy.merge(existing: existing, new: incoming, file: plannedFile(content: incoming))
        XCTAssertTrue(merged.hasPrefix("arrived_at,departed_at,latitude\n2026-05-04T09:00:00Z,,37.77"))
        XCTAssertTrue(merged.contains("2026-05-04T12:00:00Z,,37.78"))
        XCTAssertEqual(merged.components(separatedBy: "arrived_at").count - 1, 1, "header must appear once")
    }

    func testCSVAppendWithEmptyNewKeepsExisting() throws {
        let strategy = CSVAppendMergeStrategy()
        let existing = "arrived_at\n2026-05-04T09:00:00Z\n"
        let merged = try strategy.merge(existing: existing, new: "arrived_at\n", file: plannedFile(content: "arrived_at\n"))
        XCTAssertEqual(merged, existing)
    }

    func testJSONMergeConcatenatesAndDedupesVisits() throws {
        let strategy = JSONArrayMergeStrategy()
        let existing = """
        {"exportDate":"2026-05-04T09:00:00Z","visits":[{"arrivedAt":"2026-05-04T08:00:00Z","latitude":37.7}]}
        """
        let incoming = """
        {"exportDate":"2026-05-04T12:00:00Z","visits":[{"arrivedAt":"2026-05-04T08:00:00Z","latitude":37.7},{"arrivedAt":"2026-05-04T11:00:00Z","latitude":37.8}]}
        """

        let merged = try strategy.merge(existing: existing, new: incoming, file: plannedFile(content: incoming))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(merged.utf8)) as? [String: Any])
        let visits = try XCTUnwrap(object["visits"] as? [[String: Any]])
        XCTAssertEqual(visits.count, 2, "duplicate arrivedAt must be deduped")
        XCTAssertEqual(object["exportDate"] as? String, "2026-05-04T12:00:00Z", "scalars refresh from new")
    }

    func testJSONMergeHandlesTopLevelArrays() throws {
        let strategy = JSONArrayMergeStrategy()
        let existing = """
        [{"_type":"location","tst":1775000000},{"_type":"location","tst":1775000180}]
        """
        let incoming = """
        [{"_type":"location","tst":1775000180},{"_type":"location","tst":1775000360}]
        """

        let merged = try strategy.merge(existing: existing, new: incoming, file: plannedFile(content: incoming))
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(merged.utf8)) as? [[String: Any]])
        XCTAssertEqual(array.count, 3, "duplicate tst must be deduped")
    }

    func testJSONMergeThrowsOnNonJSONExisting() {
        let strategy = JSONArrayMergeStrategy()
        XCTAssertThrowsError(try strategy.merge(
            existing: "not json at all",
            new: "{\"visits\":[]}",
            file: plannedFile(content: "{}")
        ))
    }
}
