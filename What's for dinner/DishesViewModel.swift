import SwiftUI
import WidgetKit
import Combine

class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    @Published var completedDishes: [Dish] = []
    private var saveDebouncer: DispatchWorkItem?
    private var lastFirstDish: Dish?
    
    private let dataManager = DataManager.shared
    
    init() {
        loadDishes()
        loadCompletedDishes()
    }
    
    /// ✅ Laad gerechten uit DataManager en update UI
    func loadDishes() {
        DispatchQueue.main.async {
            self.dishes = self.dataManager.loadDishes()
        }
    }
    
    /// ✅ Sla gerechten op met debounce om performance te verbeteren
    func saveDishes() {
        saveDebouncer?.cancel()
        let workItem = DispatchWorkItem {
            self.dataManager.saveDishes(self.dishes)
        }
        saveDebouncer = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// ✅ Laad voltooide gerechten uit DataManager
    func loadCompletedDishes() {
        DispatchQueue.main.async {
            self.completedDishes = self.dataManager.loadCompletedDishes()
        }
    }
    
    /// ✅ Sla voltooide gerechten op via DataManager
    func saveCompletedDishes() {
        self.dataManager.saveCompletedDishes(self.completedDishes)
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
        } else {
            print("❌ Fout bij het decoderen van de JSON")
        }
    }
    
    /// ✅ Zorgt ervoor dat de UI daadwerkelijk wordt ververst
    private func updateDishes(_ newDishes: [Dish]) {
        DispatchQueue.main.async {
            self.objectWillChange.send() // 🔹 Forceer UI-update
            self.dishes = []             // 🔹 Leeg de array (triggert UI-update)
            self.dishes.append(contentsOf: newDishes) // 🔹 Voeg nieuwe gerechten toe
            self.saveDishes()            // 🔹 Opslaan voor persistentie
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
            print("❌ Fout bij het schrijven van JSON-bestand: \(error)")
            return nil
        }
    }
}
