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
        Text(label(now: now))
            .font(.subheadline)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // Een vaste maat, geen meegroeiende: "Ma" is breder dan "Vr", en
            // dan begonnen de gerechtnamen per regel op een andere plek.
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color("InfoColor-500")))
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
            // Verder dan een week vooruit zou een weekdagnaam dubbelzinnig zijn.
            // Dan de dag van de maand, want die past nog in de cirkel.
            return LocalizedStringKey(date.formatted(.dateTime.day()))
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
