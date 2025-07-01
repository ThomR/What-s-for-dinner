/// ✅ Singleton klasse verantwoordelijk voor het opslaan, laden, resetten, importeren en exporteren van gerechten via UserDefaults en App Group.
import Foundation
import WidgetKit

class DataManager {
    static let shared = DataManager()
    private let appGroup = "group.whatsfordinner.shared"
    private let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.shared")
    
    private init() {}
    
    func saveDishes(_ dishes: [Dish]) {
        guard let userDefaults = userDefaults else {
            return
        }

        do {
            let encoded = try JSONEncoder().encode(dishes)
            userDefaults.set(encoded, forKey: "dishes")
            // 🔥 FIX: userDefaults.synchronize() is verwijderd.
            // Dit is een blokkerende operatie en vaak onnodig, wat de UI kan vertragen.
            
            // 🔥 FIX: Zorg ervoor dat UI-updates altijd op de main thread worden uitgevoerd.
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }

        } catch {
            print("❌ Fout bij opslaan van gerechten: \(error)")
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
        userDefaults?.synchronize()
    }
    
    /// ✅ Exporteer gerechten naar een tijdelijk JSON-bestand met een duidelijke naam.
    func exportDishesFileURL() -> URL? {
        let dishes = loadDishes() // Laad de meest actuele gerechten
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
