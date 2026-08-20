import Foundation

/// Eén gerecht in de planning. Bewust een waarde-type zonder verwijzing naar UI
/// of opslag, zodat iPhone, Watch en beide widgets er hetzelfde mee rekenen.
struct Dish: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var emoji: String
    /// Wanneer het gerecht aan de lijst is toegevoegd. Wordt gebruikt om bij het
    /// samenvoegen van twee apparaten een voorspelbare volgorde te houden.
    var addedAt: Date

    init(id: UUID = UUID(), name: String, emoji: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.addedAt = addedAt
    }

    /// De eerste emoji, voor plekken met weinig ruimte (complicatie, cirkel).
    var primaryEmoji: String {
        String(emoji.split(separator: " ").first ?? Substring(Emoji.fallback))
    }
}

/// Een gerecht dat is gegeten, met de dag waarop dat gebeurde.
struct ServedMeal: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var name: String
    var emoji: String
    /// De dag waarop het gerecht op tafel stond, altijd het begin van die dag.
    var servedOn: Date

    init(id: UUID = UUID(), name: String, emoji: String, servedOn: Date) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.servedOn = servedOn
    }

    init(dish: Dish, servedOn: Date) {
        self.init(id: dish.id, name: dish.name, emoji: dish.emoji, servedOn: servedOn)
    }

    /// Terug naar een gerecht dat opnieuw ingepland kan worden.
    func restored(at date: Date = Date()) -> Dish {
        Dish(id: id, name: name, emoji: emoji, addedAt: date)
    }
}

enum Emoji {
    /// Wat een gerecht krijgt als er niets herkend wordt.
    static let fallback = "🍽️"
}
