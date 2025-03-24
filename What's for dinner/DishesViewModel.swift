import SwiftUI
import WidgetKit
import Combine

/// ✅ ViewModel voor het beheren van de lijst met gerechten, inclusief laden, opslaan, resetten, voltooien, importeren/exporteren en widget-updates.
class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    @Published var completedDishes: [Dish] = []
    private var lastFirstDish: Dish?

    private let dataManager = DataManager.shared
    
    init() {
        loadDishes()
        loadCompletedDishes()
    }

    /// ✅ Laad gerechten bij het opstarten
    func loadDishes() {
        DispatchQueue.main.async {
            self.dishes = self.dataManager.loadDishes()
        }
    }

    /// ✅ Sla gerechten correct op wanneer ze veranderen
    func saveDishes() {
        dataManager.saveDishes(dishes)
        WatchSessionManager.shared.syncDishesToWatch(dishes)
    }
    
    /// ✅ Laad voltooide gerechten uit DataManager
    func loadCompletedDishes() {
        DispatchQueue.main.async {
            self.completedDishes = self.dataManager.loadCompletedDishes()
        }
    }
    
    /// ✅ Sla voltooide gerechten op via DataManager
    func saveCompletedDishes() {
        dataManager.saveCompletedDishes(completedDishes)
    }
    
    /// ✅ Voeg gerecht toe aan afgeronde gerechten en sla op
    func addToCompleted(_ dish: Dish) {
        var completedDish = dish
        completedDish.completedDate = Date()
        completedDishes.append(completedDish)
        saveCompletedDishes()
    }
    
    /// ✅ Exporteer gerechten als JSON-bestand
    func exportDishesAsJSON() -> Data? {
        return try? JSONEncoder().encode(dishes)
    }
    
    /// ✅ Importeer gerechten vanuit JSON en update de UI
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            updateDishes(importedDishes)
        }
    }
    
    /// ✅ Zorgt ervoor dat de UI daadwerkelijk wordt ververst
    private func updateDishes(_ newDishes: [Dish]) {
        DispatchQueue.main.async {
            self.objectWillChange.send() // 🔹 Forceer UI-update
            self.dishes = []                  // 🔹 Leeg de array (triggert UI-update)
            self.dishes.append(contentsOf: newDishes) // 🔹 Voeg nieuwe gerechten toe
            self.saveDishes()                // 🔹 Opslaan voor persistentie
            self.notifyWidgetIfFirstDishChanged() // 🔹 Update widget indien nodig
        }
    }
    
    /// ✅ Update widget als eerste gerecht verandert
    func notifyWidgetIfFirstDishChanged() {
        guard dishes.first != lastFirstDish else { return }
        lastFirstDish = dishes.first
        
        DispatchQueue.global(qos: .background).async {
            self.dataManager.saveDishes(self.dishes)
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
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
            print("❌ Fout bij schrijven naar tijdelijk bestand: \(error)")
            return nil
        }
    }
}
