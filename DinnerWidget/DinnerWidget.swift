import WidgetKit
import SwiftUI

/// Wat er op één dag gegeten wordt.
struct DinnerWidgetEntry: TimelineEntry {
    let date: Date
    let dish: Dish?
    let upcoming: [ScheduledDish]
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
            dish: Dish(name: "Pizza", emoji: "🍕"),
            upcoming: []
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

        guard autoAdvance else {
            // Zonder automatisch doorschuiven verandert er niets bij een dagwissel.
            return [DinnerWidgetEntry(date: now, dish: plan.dishes.first, upcoming: schedule(plan, from: 0, calendar: calendar))]
        }

        return (0...Self.daysAhead).map { offset in
            let date = offset == 0 ? now : PlanSchedule.plannedDate(offset: offset, anchorDate: now, calendar: calendar)
            let served = PlanSchedule.servedCount(in: plan, at: date, calendar: calendar)
            return DinnerWidgetEntry(
                date: date,
                dish: PlanSchedule.currentDish(in: plan, at: date, calendar: calendar, autoAdvance: true),
                upcoming: schedule(plan, from: served, calendar: calendar)
            )
        }
    }

    /// De gerechten vanaf een positie, met de dag waarop ze aan de beurt zijn.
    private func schedule(_ plan: MealPlan, from index: Int, calendar: Calendar) -> [ScheduledDish] {
        guard index < plan.dishes.count else { return [] }
        return plan.dishes[index...].enumerated().map { offset, dish in
            ScheduledDish(
                dish: dish,
                position: index + offset,
                date: PlanSchedule.plannedDate(offset: index + offset, anchorDate: plan.anchorDate, calendar: calendar)
            )
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
        VStack(alignment: .leading, spacing: 2) {
            header
            if let dish = entry.dish {
                Text(dish.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Text(dish.emoji)
                        .font(.largeTitle)
                        .lineLimit(1)
                }
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                header
                if let dish = entry.dish {
                    Text(dish.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(dish.emoji)
                        .font(.largeTitle)
                } else {
                    emptyState
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // De dagen erna, zodat je in één blik de week ziet.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.upcoming.dropFirst().prefix(3)) { item in
                    HStack(spacing: 6) {
                        Text(item.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Text(item.dish.name)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var header: some View {
        Text(LocalizedStringKey("today"))
            .font(.subheadline)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .foregroundStyle(.tint)
    }

    private var emptyState: some View {
        Text(LocalizedStringKey("no_dish"))
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

#Preview(as: .systemSmall) {
    DinnerWidget()
} timeline: {
    DinnerWidgetEntry(date: .now, dish: Dish(name: "Pizza Calzone", emoji: "🍕"), upcoming: [])
    DinnerWidgetEntry(date: .now, dish: nil, upcoming: [])
}
