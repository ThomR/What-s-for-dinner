import WidgetKit
import SwiftUI

/// Wat er vandaag en morgen op tafel staat.
struct DinnerWidgetEntry: TimelineEntry {
    let date: Date
    let today: Dish?
    let tomorrow: Dish?
}

/// Levert de tijdlijn voor de widget.
///
/// Bouwt een week aan losse dagen op. Daardoor verspringt de widget om
/// middernacht uit zichzelf, ook als de app dagenlang niet geopend wordt — dat
/// was precies wat er misging: de widget wachtte op de app.
struct DinnerWidgetProvider: TimelineProvider {

    private static let daysAhead = 7

    func placeholder(in context: Context) -> DinnerWidgetEntry {
        DinnerWidgetEntry(
            date: Date(),
            today: Dish(name: "Pizza", emoji: "🍕"),
            tomorrow: Dish(name: "Tomatensoep", emoji: "🍲")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DinnerWidgetEntry) -> Void) {
        completion(entries(from: Date()).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DinnerWidgetEntry>) -> Void) {
        let now = Date()
        let timeline = Timeline(
            entries: entries(from: now),
            // Aan het eind van de week opnieuw opbouwen; wijzigingen in de app
            // duwen daarnaast zelf een verversing door.
            policy: .after(PlanSchedule.plannedDate(offset: Self.daysAhead, anchorDate: now))
        )
        completion(timeline)
    }

    private func entries(from now: Date) -> [DinnerWidgetEntry] {
        // De extensie blijft tussen twee weergaven in leven, dus niet vertrouwen
        // op wat er de vorige keer is gelezen.
        DishStore.phoneStore.invalidateCache()
        let plan = DishStore.phoneStore.load()
        let autoAdvance = Preferences.autoAdvance
        let calendar = Calendar.current

        func pair(at date: Date) -> DinnerWidgetEntry {
            let next = PlanSchedule.upcomingDishes(
                in: plan, at: date, calendar: calendar, autoAdvance: autoAdvance, count: 2
            )
            return DinnerWidgetEntry(date: date, today: next.first, tomorrow: next.dropFirst().first)
        }

        guard autoAdvance else {
            // Zonder automatisch doorschuiven verandert er niets bij een dagwissel.
            return [pair(at: now)]
        }

        return (0...Self.daysAhead).map { offset in
            pair(at: offset == 0 ? now : PlanSchedule.plannedDate(offset: offset, anchorDate: now, calendar: calendar))
        }
    }
}

struct DinnerWidgetView: View {
    let entry: DinnerWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        block(title: "today", dish: entry.today, emojiFont: .largeTitle, nameFont: .title2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
    }

    /// Twee gelijke helften: links vandaag, rechts morgen.
    private var mediumBody: some View {
        HStack(spacing: 0) {
            block(title: "today", dish: entry.today, emojiFont: .largeTitle, nameFont: .title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Divider()
                .padding(.vertical, 2)

            block(title: "tomorrow", dish: entry.tomorrow, emojiFont: .largeTitle, nameFont: .title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 12)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func block(title: LocalizedStringKey, dish: Dish?, emojiFont: Font, nameFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(.tint)

            if let dish {
                Text(dish.name)
                    .font(nameFont)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Text(dish.emoji)
                        .font(emojiFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            } else {
                Text(LocalizedStringKey("no_dish"))
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview(as: .systemMedium) {
    DinnerWidget()
} timeline: {
    DinnerWidgetEntry(
        date: .now,
        today: Dish(name: "Pizza Calzone", emoji: "🍕"),
        tomorrow: Dish(name: "Stamppot boerenkool", emoji: "🥔 🥬")
    )
    DinnerWidgetEntry(date: .now, today: nil, tomorrow: nil)
}
