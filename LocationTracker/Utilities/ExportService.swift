import Foundation
import UIKit

enum ExportFormat {
    case json
    case csv

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}

struct ExportService {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - JSON Export

    struct ExportableVisit: Codable {
        let latitude: Double
        let longitude: Double
        let arrivedAt: String
        let departedAt: String?
        let durationMinutes: Double?
        let locationName: String?
        let address: String?
        let notes: String?
    }

    struct ExportData: Codable {
        let exportDate: String
        let visits: [ExportableVisit]
    }

    static func exportToJSON(visits: [Visit]) throws -> Data {
        let exportableVisits = visits.map { visit in
            ExportableVisit(
                latitude: visit.latitude,
                longitude: visit.longitude,
                arrivedAt: iso8601Formatter.string(from: visit.arrivedAt),
                departedAt: visit.departedAt.map { iso8601Formatter.string(from: $0) },
                durationMinutes: visit.durationMinutes,
                locationName: visit.locationName,
                address: visit.address,
                notes: visit.notes
            )
        }

        let exportData = ExportData(
            exportDate: iso8601Formatter.string(from: Date()),
            visits: exportableVisits
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }

    // MARK: - CSV Export

    static func exportToCSV(visits: [Visit]) -> Data {
        var csvString = "arrived_at,departed_at,duration_minutes,latitude,longitude,location_name,address,notes\n"

        for visit in visits {
            let arrivedAt = iso8601Formatter.string(from: visit.arrivedAt)
            let departedAt = visit.departedAt.map { iso8601Formatter.string(from: $0) } ?? ""
            let duration = visit.durationMinutes.map { String(format: "%.1f", $0) } ?? ""
            let locationName = escapeCSVField(visit.locationName ?? "")
            let address = escapeCSVField(visit.address ?? "")
            let notes = escapeCSVField(visit.notes ?? "")

            let row = "\(arrivedAt),\(departedAt),\(duration),\(visit.latitude),\(visit.longitude),\(locationName),\(address),\(notes)\n"
            csvString.append(row)
        }

        return csvString.data(using: .utf8) ?? Data()
    }

    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    // MARK: - Share/Save

    static func createTemporaryFile(data: Data, format: ExportFormat) throws -> URL {
        let fileName = "location_tracker_export_\(formattedDate()).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try data.write(to: tempURL)
        return tempURL
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }

    @MainActor
    static func share(visits: [Visit], format: ExportFormat, from viewController: UIViewController? = nil) throws {
        let data: Data
        switch format {
        case .json:
            data = try exportToJSON(visits: visits)
        case .csv:
            data = exportToCSV(visits: visits)
        }

        let fileURL = try createTemporaryFile(data: data, format: format)

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )

        // Get the presenting view controller
        guard let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        presenter.present(activityVC, animated: true)
    }
}

// MARK: - Location Points Export (for continuous tracking data)

extension ExportService {
    struct ExportableLocationPoint: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: String
        let altitude: Double?
        let speed: Double?
        let horizontalAccuracy: Double
    }

    struct LocationPointsExportData: Codable {
        let exportDate: String
        let points: [ExportableLocationPoint]
    }

    static func exportLocationPointsToJSON(points: [LocationPoint]) throws -> Data {
        let exportablePoints = points.map { point in
            ExportableLocationPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: iso8601Formatter.string(from: point.timestamp),
                altitude: point.altitude,
                speed: point.speed,
                horizontalAccuracy: point.horizontalAccuracy
            )
        }

        let exportData = LocationPointsExportData(
            exportDate: iso8601Formatter.string(from: Date()),
            points: exportablePoints
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(exportData)
    }
}
