import AppIntents
import Foundation
import SwiftData

// MARK: - Current Outing Reads

/// Shared seam for reading the name of the outing IsoMe is currently recording.
///
/// Split out of the intent itself so that:
/// (a) unit tests can inject an in-memory `ModelContext` instead of the on-disk store, and
/// (b) the cycle-2 rename work (and future read intents) can reuse the same
///     active-session resolution instead of duplicating the fetch.
// TODO(cycle-2): Get Visits / Get Movements (entity-returning read intents) land after the
// entities lane; they can reuse this seam for their "current outing" scoping.
@MainActor
enum CurrentOutingReader {
    static func currentOutingName(context: ModelContext) throws -> String {
        // Mirror RenameCurrentOutingIntent's active-session lookup exactly:
        // one open (endedAt == nil) session, newest first.
        var descriptor = FetchDescriptor<RecordingSession>(
            predicate: #Predicate { session in
                session.endedAt == nil
            }
        )
        descriptor.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        descriptor.fetchLimit = 1

        guard let activeSession = try context.fetch(descriptor).first else {
            throw IsoMeIntentError.noActiveOuting
        }

        if let customName = activeSession.normalizedCustomName {
            return customName
        }

        // The app's "Outing N" default title (RecordingSessionSummary.defaultTitle) requires
        // rebuilding the full chronological session sequence — too heavy for an intent read.
        // A medium-style date of the session start is a stable, human-readable fallback.
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: activeSession.startedAt)
    }
}

struct GetCurrentOutingNameIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current Outing Name"
    static var description = IntentDescription("The name of the outing IsoMe is currently recording.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let name = try CurrentOutingReader.currentOutingName(context: IntentSupport.makeContext())
        return .result(value: name, dialog: "Current outing: \(name).")
    }
}
