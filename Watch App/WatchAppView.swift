import SwiftUI

/// De lijst op de Watch. Alleen lezen: bewerken gebeurt op de iPhone.
struct WatchAppView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Preferences.Key.showsDayLabels, store: Preferences.defaults)
    private var showsDayLabels: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isEmpty {
                    ContentUnavailableView {
                        Label(LocalizedStringKey("empty_state_message"), systemImage: "fork.knife")
                            .fontDesign(.rounded)
                    }
                } else {
                    List(store.scheduled) { item in
                        row(for: item)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
        }
        .onChange(of: scenePhase) { _, phase in
            // De Watch rekent de dagwissel zelf uit; daar is de iPhone niet
            // meer voor nodig.
            if phase == .active { store.refresh() }
        }
    }

    private func row(for item: ScheduledDish) -> some View {
        HStack {
            Text(label(for: item))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(6)
                .background(Circle().fill(Color.accentColor))
                .frame(minWidth: 24)
                .padding(.trailing, 2)
            Text(item.dish.name)
                .font(.headline)
                .fontDesign(.rounded)
                .lineLimit(2)
            Spacer()
            Text(item.dish.primaryEmoji)
                .font(.title3)
        }
        .accessibilityElement(children: .combine)
    }

    private func label(for item: ScheduledDish) -> LocalizedStringKey {
        guard showsDayLabels else {
            return LocalizedStringKey("\(item.position + 1)")
        }
        switch PlanSchedule.dayLabel(for: item.date, at: store.today) {
        case .today, .tomorrow, .weekday:
            return Self.weekdayKeys[PlanSchedule.weekdayIndex(of: item.date)]
        case .date(let date): return LocalizedStringKey(date.formatted(.dateTime.day().month(.narrow)))
        }
    }

    private static let weekdayKeys: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]
}
