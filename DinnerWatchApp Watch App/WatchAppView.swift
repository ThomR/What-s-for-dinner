import SwiftUI

struct WatchAppView: View {
    @State private var dishes: [Dish] = []
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private let daysOfWeek: [String] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    private let appGroup = "group.nl.hoyapp.client.dinner"

    var body: some View {
        NavigationView {
            VStack {
                if dishes.isEmpty {
                    Text("Geen gerechten beschikbaar")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(dishes.indices, id: \.self) { index in
                            let dish = dishes[index]
                            HStack {
                                Text(circleContent(for: index))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.trailing, 5)
                                Text(dish.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                Text(dish.emoji)
                                    .font(.title2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gerechten")
            .onAppear {
                testSharedContainer()
                loadDishes()
            }
        }
    }

    private func circleContent(for index: Int) -> String {
        if daysInsteadOfNumbers {
            let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            let dayIndex = (todayIndex + index) % 7
            return daysOfWeek[dayIndex]
        } else {
            return "\(index + 1)"
        }
    }

    private func loadDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let data = userDefaults?.data(forKey: "dishes") {
            // Debug: toon de raw JSON zodat we kunnen zien wat er opgeslagen is
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Gelezen JSON: \(jsonString)")
            }
            if let decodedDishes = try? JSONDecoder().decode([Dish].self, from: data) {
                DispatchQueue.main.async {
                    self.dishes = decodedDishes
                }
            } else {
                print("Decoderen mislukt")
                loadDummyDishes()
            }
        } else {
            print("Kon gerechten niet laden: geen data gevonden.")
            loadDummyDishes()
        }
    }

    private func loadDummyDishes() {
        let dummyDishes = [
            Dish(id: UUID(), name: "Pizza Margherita", emoji: "🍕"),
            Dish(id: UUID(), name: "Sushi Roll", emoji: "🍣"),
            Dish(id: UUID(), name: "Hamburger", emoji: "🍔"),
            Dish(id: UUID(), name: "Spaghetti Bolognese", emoji: "🍝"),
            Dish(id: UUID(), name: "Salad", emoji: "🥗")
        ]
        DispatchQueue.main.async {
            self.dishes = dummyDishes
        }
    }

    /// Test of de gedeelde container toegankelijk is vanuit de Watch-app.
    private func testSharedContainer() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        userDefaults?.set("TestData", forKey: "testKey")
        if let testData = userDefaults?.string(forKey: "testKey") {
            print("TestData: \(testData)")
        } else {
            print("Kon test data niet laden.")
        }
    }
}

struct WatchAppView_Previews: PreviewProvider {
    static var previews: some View {
        WatchAppView()
    }
}
