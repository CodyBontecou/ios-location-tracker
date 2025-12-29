import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
@Observable
final class LocationViewModel {
    var locationManager: LocationManager
    private var modelContext: ModelContext

    // Cached data
    var todayVisits: [Visit] = []
    var allVisits: [Visit] = []
    var locationPoints: [LocationPoint] = []

    // UI State
    var selectedDate: Date = Date()
    var mapDateRange: ClosedRange<Date> = Date().addingTimeInterval(-86400 * 7)...Date()
    var showingExportSheet = false
    var showingClearConfirmation = false
    var exportError: String?

    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
        locationManager.setModelContext(modelContext)

        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        loadTodayVisits()
        loadAllVisits()
        loadLocationPoints()
    }

    func loadTodayVisits() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<Visit> { visit in
            visit.arrivedAt >= startOfDay && visit.arrivedAt < endOfDay
        }

        var descriptor = FetchDescriptor<Visit>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .forward)]

        do {
            todayVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch today's visits: \(error)")
            todayVisits = []
        }
    }

    func loadAllVisits() {
        var descriptor = FetchDescriptor<Visit>()
        descriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .reverse)]

        do {
            allVisits = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch all visits: \(error)")
            allVisits = []
        }
    }

    func loadLocationPoints() {
        var descriptor = FetchDescriptor<LocationPoint>()
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        do {
            locationPoints = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch location points: \(error)")
            locationPoints = []
        }
    }

    // MARK: - Computed Properties

    var currentVisit: Visit? {
        todayVisits.first { $0.isCurrentVisit }
    }

    var visitsGroupedByDay: [(Date, [Visit])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allVisits) { visit in
            calendar.startOfDay(for: visit.arrivedAt)
        }

        return grouped.sorted { $0.key > $1.key }
    }

    func visits(for date: Date) -> [Visit] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        return allVisits.filter { visit in
            calendar.startOfDay(for: visit.arrivedAt) == startOfDay
        }.sorted { $0.arrivedAt < $1.arrivedAt }
    }

    func visitsInDateRange(_ range: ClosedRange<Date>) -> [Visit] {
        allVisits.filter { range.contains($0.arrivedAt) }
    }

    func locationPointsInDateRange(_ range: ClosedRange<Date>) -> [LocationPoint] {
        locationPoints.filter { range.contains($0.timestamp) }
    }

    func totalDuration(for visits: [Visit]) -> TimeInterval {
        visits.compactMap { $0.durationMinutes }.reduce(0, +) * 60
    }

    func formattedTotalDuration(for visits: [Visit]) -> String {
        let totalMinutes = visits.compactMap { $0.durationMinutes }.reduce(0, +)

        if totalMinutes < 60 {
            return "\(Int(totalMinutes)) min"
        } else {
            let hours = Int(totalMinutes / 60)
            let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
            if minutes == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Visit Management

    func deleteVisit(_ visit: Visit) {
        modelContext.delete(visit)
        try? modelContext.save()
        loadData()
    }

    func updateVisitNotes(_ visit: Visit, notes: String) {
        visit.notes = notes.isEmpty ? nil : notes
        try? modelContext.save()
    }

    // MARK: - Export

    func exportVisits(format: ExportFormat, dateRange: ClosedRange<Date>? = nil) {
        let visitsToExport: [Visit]
        if let range = dateRange {
            visitsToExport = visitsInDateRange(range)
        } else {
            visitsToExport = allVisits
        }

        do {
            try ExportService.share(visits: visitsToExport, format: format)
        } catch {
            exportError = error.localizedDescription
        }
    }

    // MARK: - Clear Data

    func clearAllData() {
        do {
            try modelContext.delete(model: Visit.self)
            try modelContext.delete(model: LocationPoint.self)
            try modelContext.save()
            loadData()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }

    // MARK: - Tracking Control

    func startTracking() {
        locationManager.startTracking()
    }

    func stopTracking() {
        locationManager.stopTracking()
    }

    func enableContinuousTracking() {
        locationManager.enableContinuousTracking()
    }

    func disableContinuousTracking() {
        locationManager.disableContinuousTracking()
    }
}
