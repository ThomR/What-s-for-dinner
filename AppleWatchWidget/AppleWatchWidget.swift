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
        // Haal het eerste emoji van het gerecht op, of een placeholder
        let firstEmoji = entry.dish?.emoji.split(separator: " ").first ?? "🍽️"

        switch family {
        case .accessoryInline:
            // Dit werkte al goed
            Text("\(firstEmoji) \(entry.dish?.name ?? "Geen gerecht")")
                .unredacted()

        case .accessoryCircular:
            // Toon alleen de emoji, perfect voor een kleine, ronde weergave
            Text(String(firstEmoji))
                .font(.title) // Maak de emoji wat groter
                .unredacted()

        case .accessoryCorner:
            // Toon de emoji in de hoek, eventueel met een subtiele achtergrond
            Text(String(firstEmoji))
                .font(.title3)
                .widgetLabel {
                    // Voeg de naam van het gerecht als label toe (zichtbaar bij lang drukken)
                    Text(entry.dish?.name ?? "Geen gerecht")
                }
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
