import Foundation
import WidgetKit

class DataManager {
    static let shared = DataManager()
    private let appGroup = "group.nl.hoyapp.client.dinner"
    private let userDefaults = UserDefaults(suiteName: "group.nl.hoyapp.client.dinner")
    
    private init() {}
    
    /// ✅ Laad gerechten uit UserDefaults
    func loadDishes() -> [Dish] {
        guard let data = userDefaults?.data(forKey: "dishes") else { return [] }
        return (try? JSONDecoder().decode([Dish].self, from: data)) ?? []
    }
    
    /// ✅ Sla gerechten op en update widget
    func saveDishes(_ dishes: [Dish]) {
        guard let encoded = try? JSONEncoder().encode(dishes) else { return }
        userDefaults?.set(encoded, forKey: "dishes")
        userDefaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        
        // 🔥 Stuur een notificatie naar de Widget en Watch App
        NotificationCenter.default.post(name: Notification.Name("DishesUpdated"), object: nil)
    }
    
    /// ✅ Laad afgeronde gerechten
    func loadCompletedDishes() -> [Dish] {
        guard let data = userDefaults?.data(forKey: "completedDishes") else { return [] }
        return (try? JSONDecoder().decode([Dish].self, from: data)) ?? []
    }
    
    /// ✅ Sla voltooide gerechten op
    func saveCompletedDishes(_ dishes: [Dish]) {
        guard let encoded = try? JSONEncoder().encode(dishes) else { return }
        userDefaults?.set(encoded, forKey: "completedDishes")
        userDefaults?.synchronize()
    }
    
    /// ✅ Exporteer gerechten als JSON-bestand
    func exportDishesAsJSON() -> Data? {
        return try? JSONEncoder().encode(loadDishes())
    }
    
    /// ✅ Importeer gerechten en update DataManager
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            saveDishes(importedDishes)
        } else {
            print("❌ Fout bij het decoderen van de JSON")
        }
    }
}
