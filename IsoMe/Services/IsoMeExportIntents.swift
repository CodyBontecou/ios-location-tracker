import AppIntents
import Foundation

// MARK: - Flexible Export

// TODO(cycle-2): consolidate ExportTodayDataIntent / ExportTodayOutingsIntent /
// ExportYesterdayDataIntent presets onto this flexible intent, and wire an
// AppShortcut phrase for it (phrase wiring and preset consolidation are
// deliberately deferred to a later cycle).
// TODO(cycle-2): once consolidated, deduplicate the body shared between
// ExportRunner.run(range:dataKind:format:) and its context-injectable
// overload in IsoMeIntents.swift (kept duplicated this cycle because the fleet
// protocol forbids touching the original method body).

/// App-intent mirror of `ExportOptions.DataKind` so Shortcuts can pick which
/// slice of IsoMe data a custom-range export includes.
enum IsoMeExportDataKind: String, AppEnum {
    case visits
    case points
    case outings
    case all

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Data Kind"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .visits: "Visits",
        .points: "Points",
        .outings: "Outings",
        .all: "All Data",
    ]

    var dataKind: ExportOptions.DataKind {
        switch self {
        case .visits: return .visits
        case .points: return .points
        case .outings: return .outings
        case .all: return .all
        }
    }
}

/// Resolves `ExportDataIntent`'s optional date parameters into a concrete range.
/// Kept as a standalone, injectable function so the parameter-defaulting rules
/// can be unit-tested without opening the on-disk intent store.
enum ExportDataParameterResolution {
    /// Missing start defaults to the start of today; missing end defaults to now.
    /// Throws `IsoMeIntentError.invalidDateRange` when both dates are provided
    /// inverted (start after end) — and, defensively, whenever the resolved
    /// range would be inverted (e.g. a lone future start date), since
    /// constructing an inverted `ClosedRange` would trap at runtime.
    static func dateRange(start: Date?, end: Date?, now: Date = Date()) throws -> ClosedRange<Date> {
        let resolvedStart = start ?? Calendar.current.startOfDay(for: now)
        let resolvedEnd = end ?? now
        guard resolvedStart <= resolvedEnd else {
            throw IsoMeIntentError.invalidDateRange
        }
        return resolvedStart...resolvedEnd
    }
}

struct ExportDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Data"
    static var description = IntentDescription("Export IsoMe visits, points, or outings for a chosen date range as a file.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Start Date")
    var startDate: Date?

    @Parameter(title: "End Date")
    var endDate: Date?

    @Parameter(title: "Data Kind", default: .all)
    var dataKind: IsoMeExportDataKind

    @Parameter(title: "Format", default: .json)
    var format: IsoMeExportFormat

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let range = try ExportDataParameterResolution.dateRange(start: startDate, end: endDate)
        let file = try ExportRunner.run(range: range, dataKind: dataKind.dataKind, format: format)
        return .result(value: file)
    }
}
