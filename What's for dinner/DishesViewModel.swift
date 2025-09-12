import SwiftUI
import WidgetKit
import Combine

/// ✅ ViewModel voor het beheren van de lijst met gerechten.
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

    func loadDishes() {
        self.dishes = dataManager.loadDishes()
    }

    func saveDishes() {
        dataManager.saveDishes(dishes)
    }
    
    func loadCompletedDishes() {
        self.completedDishes = dataManager.loadCompletedDishes()
    }
    
    func saveCompletedDishes() {
        dataManager.saveCompletedDishes(completedDishes)
    }
    
    func addToCompleted(_ dish: Dish) {
        var completedDish = dish
        completedDish.completedDate = Date()
        completedDishes.append(completedDish)
        saveCompletedDishes()
    }

    func restoreDish(_ dishToRestore: Dish) {
        if let index = completedDishes.firstIndex(where: { $0.id == dishToRestore.id }) {
            var dish = completedDishes.remove(at: index)
            dish.completedDate = nil
            dishes.append(dish)
            saveCompletedDishes()
            saveDishes()
        }
    }

    func autoCompleteTopDishIfNeeded() {
        guard userDefaults.bool(forKey: "autoCompleteDish") && userDefaults.bool(forKey: "daysInsteadOfNumbers") else { return }
        
        let now = Date()
        guard let lastCompletionDate = userDefaults.object(forKey: lastCompletionDateKey) as? Date else {
            userDefaults.set(now, forKey: lastCompletionDateKey)
            return
        }
        
        let startOfToday = Calendar.current.startOfDay(for: now)
        let startOfLastCompletionDay = Calendar.current.startOfDay(for: lastCompletionDate)

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
    
    func importDishes(from jsonData: Data) {
        if let importedDishes = try? JSONDecoder().decode([Dish].self, from: jsonData) {
            updateDishes(importedDishes)
        }
    }
    
    /// ✅ Zorgt ervoor dat de UI daadwerkelijk wordt ververst
    private func updateDishes(_ newDishes: [Dish]) {
        // De @Published property wrapper regelt de UI-update automatisch.
        self.dishes = newDishes
        self.saveDishes()
        self.notifyWidgetIfFirstDishChanged()
    }
    
    /// ✅ Update widget als eerste gerecht verandert
    func notifyWidgetIfFirstDishChanged() {
        guard dishes.first != lastFirstDish else { return }
        lastFirstDish = dishes.first
        
        dataManager.saveDishes(dishes)
    }
}
