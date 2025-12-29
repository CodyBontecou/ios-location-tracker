import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedVisit: Visit?
    @State private var showingDatePicker = false
    @State private var expandedDays: Set<Date> = []

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.allVisits.isEmpty {
                    ContentUnavailableView {
                        Label("No History", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Your visit history will appear here once you start tracking.")
                    }
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $viewModel.selectedDate,
                    isPresented: $showingDatePicker
                )
            }
            .onAppear {
                viewModel.loadAllVisits()
            }
            .refreshable {
                viewModel.loadAllVisits()
            }
            .navigationDestination(item: $selectedVisit) { visit in
                VisitDetailView(visit: visit, viewModel: viewModel)
            }
        }
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.visitsGroupedByDay, id: \.0) { day, visits in
                Section {
                    DaySummaryRow(
                        day: day,
                        visits: visits,
                        totalDuration: viewModel.formattedTotalDuration(for: visits),
                        isExpanded: expandedDays.contains(day)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            if expandedDays.contains(day) {
                                expandedDays.remove(day)
                            } else {
                                expandedDays.insert(day)
                            }
                        }
                    }

                    if expandedDays.contains(day) {
                        ForEach(visits.sorted { $0.arrivedAt < $1.arrivedAt }) { visit in
                            VisitRow(visit: visit)
                                .padding(.leading, 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedVisit = visit
                                }
                        }
                    }
                }
            }
        }
    }
}

struct DaySummaryRow: View {
    let day: Date
    let visits: [Visit]
    let totalDuration: String
    let isExpanded: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(visits.count) visits", systemImage: "mappin")
                    Label(totalDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    HistoryView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
