import SwiftUI
import Foundation

// Variables for each Dish
struct Dish: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var completedDate: Date? = nil
}

struct EmojiMapping {
    static let mappings: [String: [String]] = [
        "🍔": ["hamburger", "burger"],
        "🍣": ["sushi", "nigiri", "maki"],
        "🌯": ["burrito"],
        "🍕": ["pizza", "focaccia", "flammkuchen"],
        "🍝": ["pasta", "spaghetti"],
        "🥙": ["falafel", "shawarma", "shoarma", "doner"],
        "🥗": ["salad", "salade"],
        "🥔": ["potato", "aardappel", "stamppot", "rösti", "latke"],
        "🍟": ["fries", "friet", "patat", "frites"],
        "🥩": ["beef", "pork", "vlees", "steak", "biefstuk"],
        "🐟": ["fish", "vis", "zalm", "salmon"],
        "🌶️": ["chilli", "chili"],
        "🌭": ["hotdog", "sausage", "worst"],
        "🍗": ["chicken", "kip"],
        "🥘": ["stew", "stoof", "goulash", "paella"],
        "🍚": ["rice", "rijst"],
        "🍲": ["soup", "soep", "reshteh", "bibimbap"],
        "🥓": ["bacon", "spek", "carbonara"],
        "🫓": ["flat bread", "platbrood"],
        "🌮": ["taco", "taco", "quesadilla"],
        "🍛": ["curry", "curry"],
        "🍤": ["shrimp", "garnaal"],
        "🫘": ["bean", "bonen"],
        "🧑‍🍳": ["restaurant", "uiteten"],
        "🥬": ["kale", "kool"],
        "🍆": ["aubergine", "melanzane", "eggplant"],
        "🥦": ["broccoli", "broccollini"],
        "🫑": ["bell peper", "paprika"],
        "🥑": ["avocado", "guacamole"],
        "🥥": ["coconut", "kokos"],
        "🍅": ["tomato", "tomaat", "tomaten"],
        "🧅": ["onions", "uien"],
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
        "🍱": ["bento"]
    ]
}
