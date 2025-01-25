import WidgetKit
import SwiftUI

struct DinnerWidgetEntry: TimelineEntry {
    let date: Date
    let dish: Dish?
}

// Connection from the app
struct DinnerWidgetProvider: TimelineProvider {
    private let appGroup = "group.nl.hoyapp.client.dinner"
    private let widgetUpdateNotification = Notification.Name("WidgetUpdateNotification")

    init() {
        NotificationCenter.default.addObserver(forName: widgetUpdateNotification, object: nil, queue: .main) { _ in
            print("Widget notification received.")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // Show something when data is loading
    func placeholder(in context: Context) -> DinnerWidgetEntry {
        DinnerWidgetEntry(date: Date(), dish: Dish(id: UUID(), name: "Placeholder", emoji: "🍔"))
    }

    // Show something when data isn't available
    func getSnapshot(in context: Context, completion: @escaping (DinnerWidgetEntry) -> ()) {
        let entry = DinnerWidgetEntry(date: Date(), dish: Dish(id: UUID(), name: "Pizza", emoji: "🍕"))
        completion(entry)
    }

    // Receiving data for filling in the data
    func getTimeline(in context: Context, completion: @escaping (Timeline<DinnerWidgetEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: appGroup)
        let storedDishes = userDefaults?.data(forKey: "dishes")
        let decodedDishes = storedDishes.flatMap { try? JSONDecoder().decode([Dish].self, from: $0) }
        print("Decoded dishes in widget: \(decodedDishes ?? [])") // Debug log

        let firstDish = decodedDishes?.first
        let entry = DinnerWidgetEntry(date: Date(), dish: firstDish)

        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

// View for the UI of the widget
struct DinnerWidgetView: View {
    let entry: DinnerWidgetEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey("today"))
                .font(.subheadline)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.blue)
                .padding(.bottom, -5)
            if let dish = entry.dish {
                Text(dish.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0)
                Spacer()
                HStack {
                    Spacer()
                    Text(dish.emoji)
                        .font(.largeTitle)
                }
            } else {
                Text(LocalizedStringKey("no_dish"))
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundColor(.gray)
                    .padding(.leading, 10)
            }
        }
        .containerBackground(Color.clear, for: .widget)
    }
}

struct DinnerWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DinnerWidgetView(entry: DinnerWidgetEntry(
                date: Date(),
                dish: Dish(id: UUID(), name: "Pizza Calzone", emoji: "🍕")
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))

            DinnerWidgetView(entry: DinnerWidgetEntry(
                date: Date(),
                dish: Dish(id: UUID(), name: "Sushi", emoji: "🍣")
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
