import SwiftUI
import Foundation
import UniformTypeIdentifiers

// Variables for each Dish

struct Dish: Identifiable, Codable, Equatable, Transferable {
    let id: UUID
    var name: String
    var emoji: String
    var completedDate: Date? = nil

    // Voor Transferable
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct EmojiMapping {
    static let mappings: [String: [String]] = [
        "🍔": ["hamburger", "burger"],
        "🍣": ["sushi", "nigiri", "maki"],
        "🌯": ["burrito", "lumpia", "summer rolls", "loempia"],
        "🍕": ["pizza", "focaccia", "flammkuchen"],
        "🍝": ["pasta", "spaghetti", "linguine", "pappardelle"],
        "🥙": ["falafel", "shawarma", "shoarma", "doner"],
        "🥗": ["salad", "salade"],
        "🥔": ["potato", "aardappel", "stamppot", "rösti", "latke"],
        "🍟": ["fries", "friet", "patat", "frites"],
        "🥩": ["beef", "pork", "vlees", "steak", "biefstuk"],
        "🐟": ["fish", "vis", "zalm", "salmon", "kibbeling"],
        "🌶️": ["chilli", "chili", "spicy", "pittig"],
        "🌭": ["hotdog", "sausage", "worst"],
        "🍗": ["chicken", "kip"],
        "🥘": ["stew", "stoof", "goulash", "paella"],
        "🍚": ["rice", "rijst"],
        "🍲": ["soup", "soep", "reshteh", "bibimbap"],
        "🥓": ["bacon", "spek", "carbonara"],
        "🫓": ["flat bread", "platbrood"],
        "🌮": ["taco", "taco", "quesadilla"],
        "🍛": ["curry", "curry", "tonkatsu"],
        "🍤": ["shrimp", "garnaal", "ebi"],
        "🫘": ["bean", "boon"],
        "🫛": ["french beans", "sperziebonen", "edameme"],
        "🧑‍🍳": ["restaurant", "uiteten"],
        "🥬": ["kale", "kool"],
        "🍆": ["aubergine", "melanzane", "eggplant"],
        "🥦": ["broccoli", "broccollini"],
        "🫑": ["bell peper", "paprika"],
        "🥑": ["avocado", "guacamole"],
        "🥥": ["coconut", "kokos"],
        "🍅": ["tomato", "tomaat", "tomaten"],
        "🧅": ["onion", "uien"],
        "🥕": ["carrot", "wortel"],
        "🧀": ["cheese", "kaas", "paneer", "mozzarella"],
        "🌽": ["corn", "mais", "polenta"],
        "🥟": ["gyoza", "dumpling", "pierogi", "gnocchi"],
        "🥞": ["pancakes", "pannenkoeken", "poffertjes"],
        "🧇": ["waffles", "wavels"],
        "🥧": ["pie", "quiche"],
        "🔥": ["bbq", "barbeque", "teppanyaki", "gourmet"],
        "🍄‍🟫": ["mushroom", "paddestoel", "champignons", "zwammen"],
        "🧈": ["butter", "boter"],
        "🌱": ["basil", "herbs", "kruiden"],
        "🍞": ["bread"],
        "🥠": ["samosa"],
        "🥯": ["buns", "bagel"],
        "🍖": ["ribs"],
        "🍜": ["ramen"],
        "🍥": ["chashu"],
        "🍱": ["bento"],
        "🇮🇹": ["cannelloni"],
        "🍠": ["beet", "biet"],
        "🥚": ["omelet", "omelette", "frittata"],
        "🥡": ["take-out", "takeout"]
    ]
}
