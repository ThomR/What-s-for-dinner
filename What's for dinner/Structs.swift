import SwiftUI
import Foundation
import UniformTypeIdentifiers

/// ✅ Bevat de data-structuur voor gerechten (`Dish`) en een emoji-mapping helper (`EmojiMapping`).

/// Struct die een gerecht beschrijft met naam, emoji, optionele voltooiingsdatum, en ondersteuning voor drag-and-drop via Transferable.
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

/// Biedt een mapping tussen emojis en gerelateerde sleutelwoorden, gebruikt voor automatische herkenning van gerechten.
struct EmojiMapping {
    static let mappings: [String: [String]] = [
        "🍔": ["hamburger", "burger"],
        "🍣": ["sushi", "nigiri", "maki"],
        "🌯": ["burrito", "lumpia", "summer rolls", "loempia"],
        "🍕": ["pizza", "focaccia", "flammkuchen"],
        "🍝": ["pasta", "spaghetti", "linguine", "pappardelle", "tagliatelle"],
        "🥙": ["falafel", "shawarma", "shoarma", "doner"],
        "🥗": ["salad", "salade", "gado"],
        "🥔": ["potato", "aardappel", "stamppot", "rösti", "latke"],
        "🍟": ["fries", "friet", "patat", "frites"],
        "🥩": ["beef", "pork", "vlees", "steak", "biefstuk", "roast"],
        "🐟": ["fish", "vis", "zalm", "salmon", "kibbeling", "forel", "kabeljauw", "cod", "zeebaars", "roodbaars"],
        "🌶️": ["chilli", "chili", "spicy", "pittig"],
        "🌭": ["hotdog", "sausage", "worst"],
        "🍗": ["chicken", "kip"],
        "🥘": ["stew", "stoof", "goulash", "paella"],
        "🍚": ["rice", "rijst", "pokebowl"],
        "🍲": ["soup", "soep", "reshteh", "bibimbap", "gazpacho", "reshteh", "tom kha kai"],
        "🥓": ["bacon", "spek", "carbonara"],
        "🫓": ["flat bread", "platbrood", "okonomiyaki"],
        "🌮": ["taco", "quesadilla"],
        "🍛": ["curry", "tonkatsu"],
        "🦐": ["shrimp", "garnaal", "ebi"],
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
        "🧀": ["cheese", "kaas", "paneer", "mozzarella", "halloumi", "burrata"],
        "🌽": ["corn", "mais", "polenta"],
        "🥟": ["gyoza", "dumpling", "pierogi", "gnocchi", "ravioli", "empanada"],
        "🥞": ["pancakes", "pannenkoeken", "poffertjes"],
        "🧇": ["waffles", "wafels"],
        "🥧": ["pie", "quiche"],
        "🔥": ["bbq", "barbeque", "teppanyaki", "gourmet", "wok"],
        "🍄‍🟫": ["mushroom", "paddestoel", "champignons", "zwammen"],
        "🧈": ["butter", "boter"],
        "🌱": ["basil", "herbs", "kruiden"],
        "🍞": ["bread"],
        "🥠": ["samosa"],
        "🥯": ["buns", "bagel"],
        "🍖": ["ribs"],
        "🍜": ["ramen", "noodles", "noedels"],
        "🍥": ["chashu"],
        "🍱": ["bento"],
        "🇮🇹": ["cannelloni"],
        "🍠": ["beet", "biet"],
        "🥚": ["omelet", "omelette", "frittata"],
        "🥡": ["take-out", "takeout", "chinese"],
        "🧆": ["meatball", "gehaktbal"],
        "🥒": ["cucumber", "komkommer", "courgette", "zucchini"],
        "🍢": ["souvlaki", "kebab", "skewer"],
        "🌿": ["asperges", "asparagus"],
        "🍰": ["tart", "taart", "pie"],
        "🥜": ["peanut", "pinda"]
    ]
}
