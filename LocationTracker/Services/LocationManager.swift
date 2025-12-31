import Foundation
import CoreLocation
import SwiftData
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?

    // Published state
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingEnabled: Bool = false
    @Published var isContinuousTrackingEnabled: Bool = false
    @Published var continuousTrackingAutoOffHours: Double = 2.0
    @Published var currentLocation: CLLocation?
    @Published var lastError: String?

    // Continuous tracking timer
    private var continuousTrackingTimer: Timer?
    private var continuousTrackingStartTime: Date?

    // Geocoding service
    private let geocodingService = GeocodingService()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        // Restore saved state
        isTrackingEnabled = UserDefaults.standard.bool(forKey: "isTrackingEnabled")
        isContinuousTrackingEnabled = UserDefaults.standard.bool(forKey: "isContinuousTrackingEnabled")
        if UserDefaults.standard.object(forKey: "continuousTrackingAutoOffHours") != nil {
            continuousTrackingAutoOffHours = UserDefaults.standard.double(forKey: "continuousTrackingAutoOffHours")
        } else {
            continuousTrackingAutoOffHours = 2.0
        }

        authorizationStatus = locationManager.authorizationStatus
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Permission Handling

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    var canRequestAlwaysAuthorization: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .authorizedWhenInUse
    }

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var hasAlwaysPermission: Bool {
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard hasLocationPermission else {
            requestAlwaysAuthorization()
            return
        }

        isTrackingEnabled = true
        UserDefaults.standard.set(isTrackingEnabled, forKey: "isTrackingEnabled")
        updateTrackingState()
    }

    func stopTracking() {
        isTrackingEnabled = false
        isContinuousTrackingEnabled = false
        UserDefaults.standard.set(isTrackingEnabled, forKey: "isTrackingEnabled")
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
    }

    private func updateTrackingState() {
        if isTrackingEnabled && hasLocationPermission {
            locationManager.startMonitoringVisits()
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.stopMonitoringVisits()
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.stopUpdatingLocation()
        }
    }

    // MARK: - Continuous Tracking

    func enableContinuousTracking() {
        guard hasLocationPermission else { return }

        isContinuousTrackingEnabled = true
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
        continuousTrackingStartTime = Date()

        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.startUpdatingLocation()

        // Set auto-off timer (skip if set to "Never" which is 0)
        continuousTrackingTimer?.invalidate()
        continuousTrackingTimer = nil

        if continuousTrackingAutoOffHours > 0 {
            let autoOffInterval = continuousTrackingAutoOffHours * 3600
            continuousTrackingTimer = Timer.scheduledTimer(withTimeInterval: autoOffInterval, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.disableContinuousTracking()
                }
            }
        }
    }

    func disableContinuousTracking() {
        isContinuousTrackingEnabled = false
        UserDefaults.standard.set(isContinuousTrackingEnabled, forKey: "isContinuousTrackingEnabled")
        continuousTrackingTimer?.invalidate()
        continuousTrackingTimer = nil
        continuousTrackingStartTime = nil

        locationManager.stopUpdatingLocation()

        // Resume normal tracking if still enabled
        if isTrackingEnabled {
            updateTrackingState()
        }
    }

    private func updateContinuousTracking() {
        if isContinuousTrackingEnabled {
            enableContinuousTracking()
        } else {
            disableContinuousTracking()
        }
    }

    var continuousTrackingRemainingTime: TimeInterval? {
        // Return nil if auto-off is set to "Never" (0)
        guard continuousTrackingAutoOffHours > 0 else { return nil }
        guard let startTime = continuousTrackingStartTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = continuousTrackingAutoOffHours * 3600
        return max(0, total - elapsed)
    }

    // MARK: - Data Storage

    private func saveVisit(_ clVisit: CLVisit) {
        guard let context = modelContext else { return }

        // Check if this is a departure update for an existing visit
        let arrivalDate = clVisit.arrivalDate
        let latitude = clVisit.coordinate.latitude
        let longitude = clVisit.coordinate.longitude

        let predicate = #Predicate<Visit> { visit in
            visit.latitude == latitude &&
            visit.longitude == longitude &&
            visit.departedAt == nil
        }

        let descriptor = FetchDescriptor<Visit>(predicate: predicate)

        do {
            let existingVisits = try context.fetch(descriptor)

            if let existingVisit = existingVisits.first,
               clVisit.departureDate != Date.distantFuture {
                // Update departure time
                existingVisit.departedAt = clVisit.departureDate
            } else if clVisit.arrivalDate != Date.distantPast {
                // Create new visit
                let visit = Visit(
                    latitude: latitude,
                    longitude: longitude,
                    arrivedAt: arrivalDate
                )

                if clVisit.departureDate != Date.distantFuture {
                    visit.departedAt = clVisit.departureDate
                }

                context.insert(visit)

                // Trigger geocoding
                Task {
                    await geocodeVisit(visit)
                }
            }

            try context.save()
        } catch {
            lastError = "Failed to save visit: \(error.localizedDescription)"
        }
    }

    private func saveLocationPoint(_ location: CLLocation) {
        guard let context = modelContext else { return }
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100 else {
            return // Skip inaccurate readings
        }

        let point = LocationPoint(from: location)
        context.insert(point)

        do {
            try context.save()
        } catch {
            lastError = "Failed to save location point: \(error.localizedDescription)"
        }
    }

    // MARK: - Geocoding

    private func geocodeVisit(_ visit: Visit) async {
        guard !visit.geocodingCompleted else { return }

        let location = CLLocation(latitude: visit.latitude, longitude: visit.longitude)

        do {
            let result = try await geocodingService.reverseGeocode(location: location)
            visit.locationName = result.name
            visit.address = result.address
            visit.geocodingCompleted = true

            try modelContext?.save()
        } catch {
            // Mark as completed even on error to avoid retrying too often
            visit.geocodingCompleted = true
            try? modelContext?.save()
        }
    }

    func retryGeocoding(for visit: Visit) async {
        visit.geocodingCompleted = false
        await geocodeVisit(visit)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if hasLocationPermission && isTrackingEnabled {
                updateTrackingState()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            saveVisit(visit)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            currentLocation = location

            if isContinuousTrackingEnabled {
                saveLocationPoint(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    lastError = "Location access denied"
                case .network:
                    lastError = "Network error"
                default:
                    lastError = error.localizedDescription
                }
            } else {
                lastError = error.localizedDescription
            }
        }
    }
}
