import SwiftUI
import Foundation

private func addDish() {
    guard !newDishName.isEmpty else { return }
    let emojis = detectEmojis(for: newDishName)
    dishes.append(Dish(id: UUID(), name: newDishName, emoji: emojis))
    newDishName = ""
}

private func detectEmojis(for dishName: String) -> String {
    let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
        mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
    }
    let defaultEmoji = "🍽️" // Default emoji
    return matchedEmojis.isEmpty ? defaultEmoji : matchedEmojis.prefix(3).joined(separator: " ")
}

private func deleteDish(at offsets: IndexSet) {
    dishes.remove(atOffsets: offsets)
}

private func resetDishes() {
    dishes.removeAll()
}

private func loadDishes() {
    if let decoded = try? JSONDecoder().decode([Dish].self, from: storedDishes) {
        dishes = decoded
    }
}

private func saveDishes() {
    DispatchQueue.global(qos: .background).async {
        if let encoded = try? JSONEncoder().encode(dishes) {
            DispatchQueue.main.async {
                storedDishes = encoded
            }
        }
    }
}

private func toggleLock(_ dish: Dish) {
    if lockedItems.contains(dish.id) {
        lockedItems.remove(dish.id)
    } else {
        lockedItems.insert(dish.id)
    }
}

private func moveDish(from source: IndexSet, to destination: Int) {
    guard let sourceIndex = source.first else { return }
    guard destination >= 0 && destination <= dishes.count else { return }

    let movingDish = dishes[sourceIndex]
    if lockedItems.contains(movingDish.id) { return } // Prevent moving locked dishes

    dishes.move(fromOffsets: source, toOffset: destination)
}
