import SwiftUI

/// Eén gerecht in de lijst, met links de dag of het nummer.
struct DishRow: View {
    let item: ScheduledDish

    @AppStorage(Preferences.Key.showsDayLabels, store: Preferences.defaults)
    private var showsDayLabels: Bool = false

    @Environment(\.calendar) private var calendar

    /// Het moment waartegen de daglabels gerekend worden. Komt van buiten, zodat
    /// de hele lijst tegelijk verspringt zodra `PlanStore` de dag bijwerkt.
    let now: Date

    init(item: ScheduledDish, now: Date) {
        self.item = item
        self.now = now
    }

    var body: some View {
        HStack {
            marker(now: now)
            Text(item.dish.name)
                .font(.headline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .padding(8)
                .lineLimit(3)
            Spacer()
            Text(item.dish.emoji)
                .font(.largeTitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(now: now))
    }

    private func marker(now: Date) -> some View {
        let isToday = calendar.isDate(item.date, inSameDayAs: now)
        return Text(label(now: now))
            .font(.caption)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .foregroundStyle(isToday ? Color.white : Color.white.opacity(0.9))
            .padding(.horizontal, 6)
            .frame(minWidth: 30, minHeight: 30)
            .background(
                Capsule().fill(isToday ? Color("InfoColor-500") : Color("GrayColor-500"))
            )
    }

    /// Wat er in het label staat: een nummer, of de dag waarop het gerecht
    /// aan de beurt is.
    private func label(now: Date) -> LocalizedStringKey {
        guard showsDayLabels else {
            return LocalizedStringKey("\(item.position + 1)")
        }
        switch PlanSchedule.dayLabel(for: item.date, at: now, calendar: calendar) {
        case .today, .tomorrow, .weekday:
            return Self.weekdayKeys[PlanSchedule.weekdayIndex(of: item.date, calendar: calendar)]
        case .date(let date):
            return LocalizedStringKey(date.formatted(.dateTime.day().month(.abbreviated)))
        }
    }

    private func accessibilityLabel(now: Date) -> Text {
        Text(label(now: now)) + Text(verbatim: ", ") + Text(item.dish.name)
    }

    /// 0 = maandag, gelijk aan `PlanSchedule.weekdayIndex`.
    private static let weekdayKeys: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]
}
