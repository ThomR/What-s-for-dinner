import SwiftUI
import WidgetKit
import Combine

class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    private var saveDebouncer: DispatchWorkItem?
    private var lastFirstDish: Dish?

    private let appGroup = "group.nl.hoyapp.client.dinner"

    func loadDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let decoded = try? JSONDecoder().decode([Dish].self, from: userDefaults?.data(forKey: "dishes") ?? Data()) {
            DispatchQueue.main.async {
                self.dishes = decoded
            }
        }
    }

    func saveDishes() {
        saveDebouncer?.cancel()
        let workItem = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(self.dishes) {
                let userDefaults = UserDefaults(suiteName: self.appGroup)
                DispatchQueue.main.async {
                    userDefaults?.set(encoded, forKey: "dishes")
                }
            }
        }
        saveDebouncer = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    func notifyWidgetIfFirstDishChanged() {
        guard dishes.first != lastFirstDish else { return }
        lastFirstDish = dishes.first

        let userDefaults = UserDefaults(suiteName: appGroup)
        if let encoded = try? JSONEncoder().encode(dishes) {
            userDefaults?.set(encoded, forKey: "dishes")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
