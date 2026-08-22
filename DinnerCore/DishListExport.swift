import Foundation

/// Het inlezen van een gedeelde gerechtenlijst.
///
/// Delen gaat sinds versie 2 via iCloud. Een lijst als JSON-bestand versturen
/// kan niet meer, maar inlezen blijft: iemand kan nog een bestand hebben liggen
/// dat een oudere versie heeft gemaakt.
enum DishListExport {

    /// Leest een gedeelde lijst. Accepteert zowel het huidige formaat als dat van
    /// versie 1, zodat een bestand van een oudere installatie blijft werken.
    static func read(_ data: Data) -> [Dish]? {
        if let dishes = try? JSONDecoder.plan.decode([Dish].self, from: data), !dishes.isEmpty {
            return dishes
        }
        // Versie 1 schreef datums als getal en kende geen `addedAt`.
        if let legacy = try? JSONDecoder().decode([LegacyDish].self, from: data), !legacy.isEmpty {
            return legacy.map { Dish(id: $0.id, name: $0.name, emoji: $0.emoji, addedAt: Date()) }
        }
        return nil
    }

    private struct LegacyDish: Decodable {
        let id: UUID
        let name: String
        let emoji: String
    }
}
