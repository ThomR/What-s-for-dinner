import Foundation

/// Het delen van een gerechtenlijst als JSON-bestand.
///
/// Blijft bestaan naast het delen via iCloud: handig om een lijst naar iemand te
/// sturen die de app niet heeft, of om een reservekopie te maken.
enum DishListExport {

    static let fileName = "gerechtenlijst.json"

    /// Schrijft de lijst naar een tijdelijk bestand en geeft de locatie terug.
    static func write(_ dishes: [Dish]) -> URL? {
        guard !dishes.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try JSONEncoder.plan.encode(dishes).write(to: url, options: .atomic)
            return url
        } catch {
            Log.store.error("Exporteren mislukt: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

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
