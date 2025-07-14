import SwiftUI
import WidgetKit
import Combine

/// ✅ ViewModel voor het beheren van de lijst met gerechten, inclusief laden, opslaan, resetten, voltooien, importeren/exporteren en widget-updates.
class DishesViewModel: ObservableObject {
    @Published var dishes: [Dish] = []
    @Published var completedDishes: [Dish] = []
    private var lastFirstDish: Dish?

    private let dataManager = DataManager.shared
    private let userDefaults = UserDefaults.standard
    private let lastCompletionDateKey = "lastAutoCompletionDate"

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

    /// ✅ Zet een gerecht vanuit het logboek terug in de hoofdlijst
    func restoreDish(_ dishToRestore: Dish) {
        // Verwijder het gerecht uit de voltooide lijst
        if let index = completedDishes.firstIndex(where: { $0.id == dishToRestore.id }) {
            var dish = completedDishes.remove(at: index)
            
            // Reset de voltooiingsdatum
            dish.completedDate = nil
            
            // Voeg het gerecht toe aan de actieve lijst
            dishes.append(dish)
            
            // Sla beide lijsten op
            saveCompletedDishes()
            saveDishes()
        }
    }

    /// ✅ Voltooi het bovenste gerecht automatisch indien de instelling actief is
    func autoCompleteTopDishIfNeeded() {
        // 1. Controleer of de instellingen aan staan
        guard userDefaults.bool(forKey: "autoCompleteDish") && userDefaults.bool(forKey: "daysInsteadOfNumbers") else { return }
        
        let now = Date()
        
        // 2. Haal de datum van de laatste voltooiing op
        guard let lastCompletionDate = userDefaults.object(forKey: lastCompletionDateKey) as? Date else {
            // Als er nog nooit een gerecht is voltooid, doe het nu NIET, maar stel de datum in voor de toekomst.
            userDefaults.set(now, forKey: lastCompletionDateKey)
            return
        }
        
        // 🔥 FIX: Vergelijk de start van de dag (middernacht) in plaats van de hele datum.
        // Dit voorkomt problemen met tijdzones en het tijdstip van de dag.
        let startOfToday = Calendar.current.startOfDay(for: now)
        let startOfLastCompletionDay = Calendar.current.startOfDay(for: lastCompletionDate)

        // 3. Als de start van de laatste voltooiingsdag VOOR de start van vandaag ligt, voltooi het gerecht.
        if startOfLastCompletionDay < startOfToday {
            completeTopDish()
            userDefaults.set(now, forKey: lastCompletionDateKey)
        }
    }

    private func completeTopDish() {
        guard let topDish = dishes.first else { return }
        
        withAnimation {
            addToCompleted(topDish)
            dishes.removeFirst()
            saveDishes()
        }
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
}
