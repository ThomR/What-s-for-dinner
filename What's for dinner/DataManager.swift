import Foundation
import WidgetKit

class DataManager {
    static let shared = DataManager()
    private let appGroup = "group.whatsfordinner.shared"
    private let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.shared")
    
    private init() {}
    
    func saveDishes(_ dishes: [Dish]) {
        guard let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.shared") else {
            return
        }

        do {
            let encoded = try JSONEncoder().encode(dishes)
            userDefaults.set(encoded, forKey: "dishes")
            userDefaults.synchronize()

            if let data = userDefaults.data(forKey: "dishes") {
                _ = try? JSONDecoder().decode([Dish].self, from: data)
            }


        } catch {
        }
    }

    func loadDishes() -> [Dish] {
        guard let userDefaults = userDefaults else {
            return []
        }

        guard let data = userDefaults.data(forKey: "dishes") else {
            return []
        }

        do {
            let dishes = try JSONDecoder().decode([Dish].self, from: data)
            return dishes
        } catch {
            return []
        }
    }
    
    func resetUserDefaults() {
        guard let userDefaults = userDefaults else {
            return
        }

        userDefaults.removeObject(forKey: "dishes")
        userDefaults.synchronize()
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
        }
    }
}
