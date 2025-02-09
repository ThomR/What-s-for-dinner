import SwiftUI

struct WatchAppView: View {
    @State private var dishes: [Dish] = []
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false
    private let dataManager = DataManager.shared

    private let daysOfWeek: [String] = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
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
                        ForEach(dishes.indices, id: \ .self) { index in
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
                loadDishes()
                NotificationCenter.default.addObserver(forName: Notification.Name("DishesUpdated"), object: nil, queue: .main) { _ in
                    loadDishes()
                }
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
        DispatchQueue.main.async {
            self.dishes = dataManager.loadDishes()
        }
    }
}

struct WatchAppView_Previews: PreviewProvider {
    static var previews: some View {
        WatchAppView()
    }
}
