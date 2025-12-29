import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LocationViewModel?
    @State private var locationManager = LocationManager()

    var body: some View {
        Group {
            if let viewModel = viewModel {
                TabView {
                    TodayView(viewModel: viewModel)
                        .tabItem {
                            Label("Today", systemImage: "clock.fill")
                        }

                    HistoryView(viewModel: viewModel)
                        .tabItem {
                            Label("History", systemImage: "calendar")
                        }

                    LocationMapView(viewModel: viewModel)
                        .tabItem {
                            Label("Map", systemImage: "map.fill")
                        }

                    SettingsView(viewModel: viewModel)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = LocationViewModel(
                    modelContext: modelContext,
                    locationManager: locationManager
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
            viewModel?.loadData()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Visit.self, LocationPoint.self], inMemory: true)
}
