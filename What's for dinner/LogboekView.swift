import SwiftUI

/// Wat er al gegeten is, nieuwste bovenaan, gegroepeerd per maand.
struct LogboekView: View {
    @EnvironmentObject private var store: PlanStore
    @State private var showClearAlert = false

    private var groups: [(title: String, meals: [ServedMeal])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.log) { meal in
            calendar.dateInterval(of: .month, for: meal.servedOn)?.start ?? meal.servedOn
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (title: $0.key.formatted(.dateTime.month(.wide).year()), meals: $0.value) }
    }

    var body: some View {
        Group {
            if store.log.isEmpty {
                ContentUnavailableView {
                    Label(LocalizedStringKey("no_completed_dishes_message"), systemImage: "book.closed")
                        .fontDesign(.rounded)
                }
            } else {
                List {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.meals) { meal in
                                row(for: meal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("completed_dishes_title"))
        .toolbar {
            if !store.log.isEmpty {
                Button(role: .destructive) {
                    showClearAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(LocalizedStringKey("clear_history"))
            }
        }
        .alert(LocalizedStringKey("clear_history_confirm"), isPresented: $showClearAlert) {
            Button(LocalizedStringKey("yes"), role: .destructive) {
                withAnimation { store.clearLog() }
            }
            Button(LocalizedStringKey("cancel"), role: .cancel) {}
        }
    }

    private func row(for meal: ServedMeal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .lineLimit(2)
                Text(meal.servedOn.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(meal.emoji)
                .font(.largeTitle)
        }
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                withAnimation { store.restore(meal) }
            } label: {
                Label(LocalizedStringKey("restore_dish"), systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
    }
}
