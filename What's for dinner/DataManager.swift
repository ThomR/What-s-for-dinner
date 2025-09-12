/// ✅ Singleton klasse verantwoordelijk voor het opslaan, laden, resetten, importeren en exporteren van gerechten via UserDefaults en App Group.
import Foundation
import WidgetKit

class DataManager {
    static let shared = DataManager()
    private let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.shared")

    // ✅ Gebruik een struct voor keys om typefouten te voorkomen
    private enum Keys {
        static let dishes = "dishes"
        static let completedDishes = "completedDishes"
    }
    
    private init() {}

    // 1. ✅ Generieke helper-functie voor het laden van data
    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    // 2. ✅ Generieke helper-functie voor het opslaan van data
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults?.set(data, forKey: key)
        } catch {
            print("❌ Fout bij opslaan voor key '\(key)': \(error)")
        }
    }

    // De publieke functies worden nu veel simpeler en efficiënter
    func saveDishes(_ dishes: [Dish]) {
        save(dishes, forKey: Keys.dishes)
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func loadDishes() -> [Dish] {
        return load(forKey: Keys.dishes) ?? []
    }
    
    func saveCompletedDishes(_ dishes: [Dish]) {
        save(dishes, forKey: Keys.completedDishes)
    }

    func loadCompletedDishes() -> [Dish] {
        return load(forKey: Keys.completedDishes) ?? []
    }
    
    func resetUserDefaults() {
        userDefaults?.removeObject(forKey: Keys.dishes)
        userDefaults?.removeObject(forKey: Keys.completedDishes)
    }
    
    /// ✅ Importeer gerechten en update DataManager
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            saveDishes(importedDishes)
        }
    }
    
    /// ✅ Exporteer gerechten naar een tijdelijk JSON-bestand met een duidelijke naam.
    func exportDishesFileURL() -> URL? {
        let dishes = loadDishes()
        guard let data = try? JSONEncoder().encode(dishes) else { return nil }
        
        let fileName = "MijnGerechtenlijst.json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Fout bij schrijven naar tijdelijk bestand: \(error)")
            return nil
        }
    }
}
