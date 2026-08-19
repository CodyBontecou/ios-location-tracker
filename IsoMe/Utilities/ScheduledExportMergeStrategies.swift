import Foundation
import ExportKit

/// How interval scheduled exports keep the day's file consistent.
enum ScheduledExportFileMode: String, CaseIterable {
    /// Re-export the full day so far and overwrite the day's file (default).
    case rewrite

    /// Add only the records captured since the last successful run.
    case append
}

enum ScheduledExportMergeError: LocalizedError {
    case unmergeableJSON

    var errorDescription: String? {
        switch self {
        case .unmergeableJSON:
            return String(localized: "The existing export file could not be merged; the day's file was rewritten instead.")
        }
    }
}

/// Per-format append policy for interval scheduled exports.
///
/// Row formats (CSV) and JSON payloads can be extended incrementally with a
/// merge strategy; GPX and KML are XML containers and are always fully
/// rewritten with the complete day-so-far snapshot.
enum IsoMeScheduledExportWritePolicy {
    /// Formats whose day file can be extended incrementally.
    static let appendableFormats: Set<ExportFormat> = [
        .csv, .json, .markdown, .owntracks, .overland, .geojson,
    ]

    struct Resolved {
        /// Writer mode passed to `ExportFileWriter`.
        var writeMode: ExportWriteMode
        /// Merge strategy keyed for the scheduled format, if any.
        var mergeStrategy: (any ExportMergeStrategy)?
        /// Whether the export window should cover only records since the last run.
        var usesDeltaWindow: Bool
    }

    /// Full-day overwrite (also the fallback for append with container formats).
    static let rewrite = Resolved(writeMode: .overwrite, mergeStrategy: nil, usesDeltaWindow: false)

    static func resolve(format: ExportFormat, fileMode: ScheduledExportFileMode) -> Resolved {
        guard fileMode == .append, appendableFormats.contains(format) else {
            return rewrite
        }
        return Resolved(
            writeMode: .update,
            mergeStrategy: mergeStrategy(for: format),
            usesDeltaWindow: true
        )
    }

    static func mergeStrategy(for format: ExportFormat) -> (any ExportMergeStrategy)? {
        switch format {
        case .csv:
            return CSVAppendMergeStrategy()
        case .json, .geojson, .owntracks, .overland:
            return JSONArrayMergeStrategy()
        case .markdown:
            return MarkdownMergeStrategy()
        case .gpx, .kml:
            return nil
        }
    }
}

/// Appends CSV rows to an existing export, dropping the new payload's header
/// row because the existing file already carries it.
struct CSVAppendMergeStrategy: ExportMergeStrategy {
    func merge(existing: String, new: String, file: PlannedExportFile) throws -> String {
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return new }

        var lines = new.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return existing }
        lines.removeFirst()

        let body = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !body.isEmpty else { return existing }

        return trimmedExisting + "\n" + body + "\n"
    }
}

/// Merges two JSON export payloads: top-level arrays (and array-valued fields
/// of top-level objects) are concatenated, keeping the first occurrence of
/// each record keyed by a stable identity field; scalar fields refresh from
/// the new payload. Handles object roots (`{ "visits": [...] }`), top-level
/// arrays (OwnTracks), and FeatureCollection-style payloads (Overland, GeoJSON).
struct JSONArrayMergeStrategy: ExportMergeStrategy {
    private static let identityKeys = ["id", "arrivedAt", "timestamp", "tst", "startedAt", "started_at"]

    func merge(existing: String, new: String, file: PlannedExportFile) throws -> String {
        guard let existingData = existing.data(using: .utf8),
              let newData = new.data(using: .utf8) else {
            throw ScheduledExportMergeError.unmergeableJSON
        }

        let existingValue = try JSONSerialization.jsonObject(with: existingData)
        let newValue = try JSONSerialization.jsonObject(with: newData)

        let merged: Any
        if let existingArray = existingValue as? [Any], let newArray = newValue as? [Any] {
            merged = Self.dedupe(existingArray + newArray)
        } else if let existingObject = existingValue as? [String: Any],
                  let newObject = newValue as? [String: Any] {
            var mergedObject = newObject
            for (key, value) in newObject {
                guard let newArray = value as? [Any],
                      let existingArray = existingObject[key] as? [Any] else { continue }
                mergedObject[key] = Self.dedupe(existingArray + newArray)
            }
            merged = mergedObject
        } else {
            throw ScheduledExportMergeError.unmergeableJSON
        }

        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private static func dedupe(_ values: [Any]) -> [Any] {
        var seen = Set<String>()
        var result: [Any] = []
        for value in values {
            guard let object = value as? [String: Any], let identity = identityKey(for: object) else {
                result.append(value)
                continue
            }
            if seen.insert(identity).inserted {
                result.append(value)
            }
        }
        return result
    }

    private static func identityKey(for object: [String: Any]) -> String? {
        for key in identityKeys {
            if let value = object[key] {
                return "\(key)=\(value)"
            }
        }
        return nil
    }
}
