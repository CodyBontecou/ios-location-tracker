import SwiftUI
import SwiftData

struct TodayView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedVisit: Visit?

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.locationManager.hasLocationPermission {
                    PermissionRequestView(locationManager: viewModel.locationManager)
                } else if viewModel.todayVisits.isEmpty && viewModel.todayLocationPoints.isEmpty {
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
                viewModel.loadTodayLocationPoints()
            }
            .refreshable {
                viewModel.loadTodayVisits()
                viewModel.loadTodayLocationPoints()
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(visit: visit, viewModel: viewModel)
            }
        }
    }

    private var visitsList: some View {
        List {
            // Tracking Activity Section
            if !viewModel.todayLocationPoints.isEmpty {
                Section {
                    TrackingActivityCard(viewModel: viewModel)
                } header: {
                    Text("Tracking Activity")
                }
            }

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
            Label("No Activity Yet", systemImage: "location.slash")
        } description: {
            if isTracking {
                Text("Your location activity will appear here. Enable continuous tracking to record your path.")
            } else {
                Text("Enable location tracking in Settings to start recording your activity.")
            }
        }
    }
}

struct TrackingActivityCard: View {
    let viewModel: LocationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats row
            HStack(spacing: 20) {
                StatItem(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: viewModel.formattedTodayDistance,
                    label: "Distance"
                )

                StatItem(
                    icon: "clock",
                    value: viewModel.formattedTodayTrackingDuration,
                    label: "Duration"
                )

                StatItem(
                    icon: "mappin.circle",
                    value: "\(viewModel.todayLocationPoints.count)",
                    label: "Points"
                )
            }

            // Timeline
            if viewModel.todayLocationPoints.count >= 2 {
                Divider()
                TrackingTimeline(points: viewModel.todayLocationPoints)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrackingTimeline: View {
    let points: [LocationPoint]

    private var segments: [TimelineSegment] {
        guard points.count >= 2 else { return [] }

        var result: [TimelineSegment] = []
        var segmentStart = points[0]
        var segmentPoints: [LocationPoint] = [segmentStart]
        var isMoving = false

        for i in 1..<points.count {
            let prev = points[i-1]
            let curr = points[i]
            let distance = prev.distance(to: curr)
            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            let speed = timeDiff > 0 ? distance / timeDiff : 0

            // Consider moving if speed > 1 m/s (3.6 km/h)
            let currentlyMoving = speed > 1.0

            if currentlyMoving != isMoving && segmentPoints.count > 1 {
                // State changed, save current segment
                result.append(TimelineSegment(
                    startTime: segmentStart.timestamp,
                    endTime: prev.timestamp,
                    isMoving: isMoving,
                    pointCount: segmentPoints.count
                ))
                segmentStart = prev
                segmentPoints = [prev]
                isMoving = currentlyMoving
            }
            segmentPoints.append(curr)
        }

        // Add final segment
        if let last = points.last, segmentPoints.count > 1 {
            result.append(TimelineSegment(
                startTime: segmentStart.timestamp,
                endTime: last.timestamp,
                isMoving: isMoving,
                pointCount: segmentPoints.count
            ))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let first = points.first, let last = points.last {
                HStack {
                    Text(first.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(last.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Visual timeline bar
                GeometryReader { geo in
                    let totalDuration = last.timestamp.timeIntervalSince(first.timestamp)
                    HStack(spacing: 1) {
                        ForEach(segments) { segment in
                            let segmentDuration = segment.endTime.timeIntervalSince(segment.startTime)
                            let width = totalDuration > 0 ? (segmentDuration / totalDuration) * geo.size.width : 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segment.isMoving ? Color.blue : Color.blue.opacity(0.3))
                                .frame(width: max(2, width))
                        }
                    }
                }
                .frame(height: 8)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 12, height: 8)
                        Text("Moving")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 8)
                        Text("Stationary")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct TimelineSegment: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let isMoving: Bool
    let pointCount: Int
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
