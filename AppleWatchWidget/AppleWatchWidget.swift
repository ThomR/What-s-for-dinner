import WidgetKit
import SwiftUI

struct WatchDinnerWidgetEntry: TimelineEntry {
    let date: Date
    let dish: Dish?
}

/// Complicatie-tijdlijn voor de Watch.
///
/// Net als op de iPhone een reeks losse dagen, zodat de complicatie 's nachts
/// vanzelf verspringt zonder dat de iPhone of de Watch-app open hoeft te zijn.
struct WatchDinnerWidgetProvider: TimelineProvider {

    private static let daysAhead = 7

    func placeholder(in context: Context) -> WatchDinnerWidgetEntry {
        WatchDinnerWidgetEntry(date: Date(), dish: Dish(name: "Pizza", emoji: "🍕"))
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchDinnerWidgetEntry) -> Void) {
        completion(entries(from: Date()).first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDinnerWidgetEntry>) -> Void) {
        let now = Date()
        completion(Timeline(
            entries: entries(from: now),
            policy: .after(PlanSchedule.plannedDate(offset: Self.daysAhead, anchorDate: now))
        ))
    }

    private func entries(from now: Date) -> [WatchDinnerWidgetEntry] {
        DishStore.watchStore.invalidateCache()
        let plan = DishStore.watchStore.load()
        let calendar = Calendar.current

        guard Preferences.autoAdvance else {
            return [WatchDinnerWidgetEntry(date: now, dish: plan.dishes.first)]
        }

        return (0...Self.daysAhead).map { offset in
            let date = offset == 0 ? now : PlanSchedule.plannedDate(offset: offset, anchorDate: now, calendar: calendar)
            return WatchDinnerWidgetEntry(
                date: date,
                dish: PlanSchedule.currentDish(in: plan, at: date, calendar: calendar, autoAdvance: true)
            )
        }
    }
}

struct WatchDinnerWidgetView: View {
    let entry: WatchDinnerWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var emoji: String {
        entry.dish?.primaryEmoji ?? Emoji.fallback
    }

    private var name: Text {
        if let dish = entry.dish {
            return Text(dish.name)
        }
        return Text(LocalizedStringKey("no_dish"))
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            (Text(emoji) + Text(verbatim: " ") + name)
                .unredacted()

        case .accessoryCircular:
            Text(emoji)
                .font(.title)
                .unredacted()

        case .accessoryCorner:
            Text(emoji)
                .font(.title3)
                .widgetLabel { name }
                .unredacted()

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("today"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(emoji)
                    name
                        .font(.headline)
                        .fontDesign(.rounded)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .unredacted()

        default:
            EmptyView()
        }
    }
}

@main
struct WatchDinnerWidget: Widget {
    let kind = "WatchDinnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchDinnerWidgetProvider()) { entry in
            WatchDinnerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("What's for Dinner")
        .description(String(localized: "widget_description"))
        .supportedFamilies([.accessoryInline, .accessoryCorner, .accessoryCircular, .accessoryRectangular])
    }
}
