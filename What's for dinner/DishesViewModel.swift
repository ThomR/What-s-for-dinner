import SwiftUI
import WidgetKit
import Combine

class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    private var saveDebouncer: DispatchWorkItem?
    private var lastFirstDish: Dish?

    private let appGroup = "group.nl.hoyapp.client.dinner"

    /// Export dishes as JSON
    func exportDishesAsJSON() -> Data? {
        return try? JSONEncoder().encode(dishes)
    }

    /// Import dishes from JSON
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            DispatchQueue.main.async {
                self.dishes = importedDishes
            }
        }
    }
    
    /// Function to load dishes from UserDefaults
    func loadDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let data = userDefaults?.data(forKey: "dishes"),
           let decoded = try? JSONDecoder().decode([Dish].self, from: data) {
            DispatchQueue.main.async {
                self.dishes = decoded
            }
        }
    }

    /// Function to save dishes into UserDefaults
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

    /// Updated notifyWidgetIfFirstDishChanged: heavy tasks offloaden naar achtergrondthread
    func notifyWidgetIfFirstDishChanged() {
        guard dishes.first != lastFirstDish else { return }
        lastFirstDish = dishes.first

        DispatchQueue.global(qos: .background).async {
            if let encoded = try? JSONEncoder().encode(self.dishes) {
                let userDefaults = UserDefaults(suiteName: self.appGroup)
                userDefaults?.set(encoded, forKey: "dishes")
            }
            // Vernieuw de widget op het hoofdthread
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    @Published var completedDishes: [Dish] = []

    /// Show all completed dishes in Logboek
    func loadCompletedDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let data = userDefaults?.data(forKey: "completedDishes"),
           let decoded = try? JSONDecoder().decode([Dish].self, from: data) {
            DispatchQueue.main.async {
                self.completedDishes = decoded
            }
        }
    }

    /// Save dishes to CompletedDishes
    func saveCompletedDishes() {
        if let encoded = try? JSONEncoder().encode(completedDishes) {
            let userDefaults = UserDefaults(suiteName: appGroup)
            DispatchQueue.main.async {
                userDefaults?.set(encoded, forKey: "completedDishes")
            }
        }
    }
    
    func addToCompleted(_ dish: Dish) {
        var completedDish = dish
        completedDish.completedDate = Date() // Voeg huidige datum toe
        completedDishes.append(completedDish)
        saveCompletedDishes()
    }
}
