import WidgetKit
import SwiftUI

struct WatchDinnerWidgetEntry: TimelineEntry {
    let date: Date
    let dish: Dish?
}

struct WatchDinnerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchDinnerWidgetEntry {
        WatchDinnerWidgetEntry(date: Date(), dish: Dish(id: UUID(), name: "Placeholder", emoji: "🍔"))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WatchDinnerWidgetEntry) -> ()) {
        completion(WatchDinnerWidgetEntry(date: Date(), dish: loadFirstDish()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDinnerWidgetEntry>) -> ()) {
        let entry = WatchDinnerWidgetEntry(date: Date(), dish: loadFirstDish())
        completion(Timeline(entries: [entry], policy: .never))
    }
    
    private func loadFirstDish() -> Dish? {
        let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.watchshared")
        if let data = userDefaults?.data(forKey: "watchDishes"),
           let dishes = try? JSONDecoder().decode([Dish].self, from: data) {
            return dishes.first
        }
        return nil
    }
}

struct WatchDinnerWidgetView: View {
    var entry: WatchDinnerWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.dish?.emoji.split(separator: " ").first ?? "🍽️") \(entry.dish?.name ?? "Geen gerecht")")
                .unredacted()

        case .accessoryCircular:
            Text("👍") // Of Image(systemName: "star.fill")
                .unredacted()
        case .accessoryCorner:
            Image(systemName: "heart.fill")
                .unredacted()
            
        default:
            EmptyView()
        }
    }
}

@main
struct WatchDinnerWidget: Widget {
    let kind: String = "WatchDinnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchDinnerWidgetProvider()) { entry in
            WatchDinnerWidgetView(entry: entry)
        }
        .configurationDisplayName("What's for Dinner")
        .description("Show your dish")
        .supportedFamilies([.accessoryInline, .accessoryCorner, .accessoryCircular])
    }
}
