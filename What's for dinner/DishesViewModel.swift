import SwiftUI
import WidgetKit
import Combine

class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    private var saveDebouncer: DispatchWorkItem?
    private var lastFirstDish: Dish?

    private let appGroup = "group.nl.hoyapp.client.dinner"

    /// ✅ Exporteer gerechten als JSON-bestand
    func exportDishesAsJSON() -> Data? {
        return try? JSONEncoder().encode(dishes)
    }

    /// ✅ Importeer gerechten en forceer een UI-update
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            updateDishes(importedDishes)
        } else {
            print("❌ Fout bij het decoderen van de JSON")
        }
    }

    /// ✅ Zorgt ervoor dat de UI daadwerkelijk wordt ververst
    private func updateDishes(_ newDishes: [Dish]) {
        DispatchQueue.main.async {
            self.objectWillChange.send() // 🔹 Dwing SwiftUI om de wijziging te detecteren
            self.dishes = []             // 🔹 Leeg de array (triggert UI-update)
            self.dishes.append(contentsOf: newDishes) // 🔹 Voeg nieuwe gerechten toe
            self.saveDishes()            // 🔹 Opslaan voor persistentie
            self.notifyWidgetIfFirstDishChanged() // 🔹 Update widget indien nodig
            print("✅ Gerechtenlijst succesvol geüpdatet en UI direct vernieuwd!")
        }
    }
    
    /// ✅ Laad gerechten uit UserDefaults en update UI
    func loadDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let data = userDefaults?.data(forKey: "dishes"),
           let decoded = try? JSONDecoder().decode([Dish].self, from: data) {
            DispatchQueue.main.async {
                self.dishes = decoded
                self.notifyWidgetIfFirstDishChanged()
                print("✅ Gerechtenlijst geladen uit UserDefaults")
            }
        }
    }

    /// ✅ Sla gerechten op in UserDefaults met een debounce (voorkomt onnodige opslag)
    func saveDishes() {
        saveDebouncer?.cancel()
        let workItem = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(self.dishes) {
                let userDefaults = UserDefaults(suiteName: self.appGroup)
                DispatchQueue.main.async {
                    userDefaults?.set(encoded, forKey: "dishes")
                    print("💾 Gerechtenlijst opgeslagen in UserDefaults")
                }
            }
        }
        saveDebouncer = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// ✅ Update widget als eerste gerecht verandert
    func notifyWidgetIfFirstDishChanged() {
        guard dishes.first != lastFirstDish else { return }
        lastFirstDish = dishes.first

        DispatchQueue.global(qos: .background).async {
            if let encoded = try? JSONEncoder().encode(self.dishes) {
                let userDefaults = UserDefaults(suiteName: self.appGroup)
                userDefaults?.set(encoded, forKey: "dishes")
            }
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                print("📢 Widget geüpdatet met nieuwe gerechtenlijst")
            }
        }
    }
    
    @Published var completedDishes: [Dish] = []

    /// ✅ Laad afgeronde gerechten in Logboek
    func loadCompletedDishes() {
        let userDefaults = UserDefaults(suiteName: appGroup)
        if let data = userDefaults?.data(forKey: "completedDishes"),
           let decoded = try? JSONDecoder().decode([Dish].self, from: data) {
            DispatchQueue.main.async {
                self.completedDishes = decoded
                print("✅ Voltooide gerechten geladen uit UserDefaults")
            }
        }
    }

    /// ✅ Sla voltooide gerechten op in UserDefaults
    func saveCompletedDishes() {
        if let encoded = try? JSONEncoder().encode(completedDishes) {
            let userDefaults = UserDefaults(suiteName: appGroup)
            DispatchQueue.main.async {
                userDefaults?.set(encoded, forKey: "completedDishes")
                print("💾 Voltooide gerechten opgeslagen in UserDefaults")
            }
        }
    }
    
    /// ✅ Voeg gerecht toe aan afgeronde gerechten
    func addToCompleted(_ dish: Dish) {
        var completedDish = dish
        completedDish.completedDate = Date()
        completedDishes.append(completedDish)
        saveCompletedDishes()
    }
    
    /// ✅ Exporteer gerechten naar een tijdelijk JSON-bestand met een duidelijke naam
    func exportDishesFileURL() -> URL? {
        guard let data = try? JSONEncoder().encode(dishes) else { return nil }
        let fileName = "MijnGerechtenlijst.json"  // 🔹 Aangepaste bestandsnaam
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Fout bij het schrijven van JSON-bestand: \(error)")
            return nil
        }
    }
}
