import SwiftUI

struct TodayView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedVisit: Visit?

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.locationManager.hasLocationPermission {
                    PermissionRequestView(locationManager: viewModel.locationManager)
                } else if viewModel.todayVisits.isEmpty {
                    EmptyTodayView(isTracking: viewModel.locationManager.isTrackingEnabled)
                } else {
                    visitsList
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    trackingStatusIndicator
                }
            }
            .onAppear {
                viewModel.loadTodayVisits()
            }
            .refreshable {
                viewModel.loadTodayVisits()
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(visit: visit, viewModel: viewModel)
            }
        }
    }

    private var visitsList: some View {
        List {
            if let currentVisit = viewModel.currentVisit {
                Section {
                    CurrentVisitCard(visit: currentVisit)
                        .onTapGesture {
                            selectedVisit = currentVisit
                        }
                }
            }

            Section {
                ForEach(viewModel.todayVisits.filter { !$0.isCurrentVisit }.reversed()) { visit in
                    VisitRow(visit: visit)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVisit = visit
                        }
                }
            } header: {
                if !viewModel.todayVisits.filter({ !$0.isCurrentVisit }).isEmpty {
                    Text("Earlier Today")
                }
            }
        }
    }

    private var trackingStatusIndicator: some View {
        HStack(spacing: 4) {
            if viewModel.locationManager.isContinuousTrackingEnabled {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Recording")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if viewModel.locationManager.isTrackingEnabled {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Tracking")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CurrentVisitCard: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("Current Location")
                    .font(.headline)
                Spacer()
                Text(visit.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(visit.displayName)
                .font(.title3)
                .fontWeight(.medium)

            if let address = visit.address {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Arrived at \(visit.arrivedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VisitRow: View {
    let visit: Visit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(visit.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(visit.formattedTimeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(visit.formattedDuration)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct EmptyTodayView: View {
    let isTracking: Bool

    var body: some View {
        ContentUnavailableView {
            Label("No Visits Yet", systemImage: "mappin.slash")
        } description: {
            if isTracking {
                Text("Your visits will appear here as you move throughout the day.")
            } else {
                Text("Enable location tracking in Settings to start recording your visits.")
            }
        }
    }
}

struct PermissionRequestView: View {
    @Bindable var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Location Tracker needs access to your location to record the places you visit throughout the day.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if locationManager.authorizationStatus == .denied {
                VStack(spacing: 16) {
                    Text("Location access was denied. Please enable it in Settings.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Button("Allow Always") {
                        locationManager.requestAlwaysAuthorization()
                    }
                    .buttonStyle(.borderedProminent)

                    Text("\"Always\" permission enables background tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview {
    TodayView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
