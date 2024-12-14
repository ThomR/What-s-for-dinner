import SwiftUI

struct WatchAppView: View {
    @State private var dishes: [Dish] = []

    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]

    var body: some View {
        List {
            ForEach(dishes.indices, id: \ .self) { index in
                let dish = dishes[index]
                HStack {
                    Text(circleContent(for: index))
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.trailing, 5)

                    VStack(alignment: .leading) {
                        Text(dish.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(dish.emoji)
                            .font(.title)
                    }
                }
            }
        }
        .onAppear(perform: loadDishes)
        .navigationTitle(LocalizedStringKey("dishes"))
    }

    private func circleContent(for index: Int) -> String {
        if daysInsteadOfNumbers {
            let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            let dayIndex = (todayIndex + index) % 7
            return daysOfWeek[dayIndex].stringValue
        } else {
            return "\(index + 1)"
        }
    }

    private func loadDishes() {
        let userDefaults = UserDefaults(suiteName: "group.whatsfordinner")
        if let decoded = try? JSONDecoder().decode([Dish].self, from: userDefaults?.data(forKey: "dishes") ?? Data()) {
            dishes = decoded
        }
    }
}

struct WatchAppView_Previews: PreviewProvider {
    static var previews: some View {
        WatchAppView()
    }
}
