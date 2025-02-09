import WidgetKit
import SwiftUI

struct DinnerWidgetEntry: TimelineEntry {
    let date: Date
    let dish: Dish?
}

// Connection from the app
struct DinnerWidgetProvider: TimelineProvider {
    private let dataManager = DataManager.shared
    
    init() {
        NotificationCenter.default.addObserver(forName: Notification.Name("DishesUpdated"), object: nil, queue: .main) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // Show something when data is loading
    func placeholder(in context: Context) -> DinnerWidgetEntry {
        DinnerWidgetEntry(date: Date(), dish: Dish(id: UUID(), name: "Placeholder", emoji: "🍔"))
    }
    
    // Show something when data isn't available
    func getSnapshot(in context: Context, completion: @escaping (DinnerWidgetEntry) -> ()) {
        let dishes = dataManager.loadDishes()
        let entry = DinnerWidgetEntry(date: Date(), dish: dishes.first)
        completion(entry)
    }
    
    // Receiving data for filling in the widget
    func getTimeline(in context: Context, completion: @escaping (Timeline<DinnerWidgetEntry>) -> ()) {
        let dishes = dataManager.loadDishes()
        let firstDish = dishes.first
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
        DinnerWidgetView(entry: DinnerWidgetEntry(
            date: Date(),
            dish: Dish(id: UUID(), name: "Pizza Calzone", emoji: "🍕")
        ))
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
