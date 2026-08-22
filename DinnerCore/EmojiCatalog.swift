import Foundation

/// Eén emoji met de woorden die eraan gekoppeld zijn.
struct EmojiKeywords: Sendable {
    let emoji: String
    let keywords: [String]
}

/// De woordenlijst waarmee gerechten een emoji krijgen.
///
/// Twee lagen. `curated` is met de hand onderhouden en gaat altijd voor: daar
/// staan keuzes in die geen woordenboek weet ("carbonara" hoort bij spek,
/// "uiteten" bij de kok). `EmojiCatalogData` komt uit de Unicode CLDR-data en
/// vult de rest aan — zie Tools/generate-emoji-catalog.py.
enum EmojiCatalog {

    /// Handmatige mappings. Nieuwe gerechten horen hier, niet in de gegenereerde lijst.
    static let curated: [EmojiKeywords] = [
        .init(emoji: "🍔", keywords: ["hamburger", "burger"]),
        .init(emoji: "🍣", keywords: ["sushi", "nigiri", "maki", "sashimi"]),
        .init(emoji: "🌯", keywords: ["burrito", "lumpia", "summer rolls", "loempia", "wrap"]),
        .init(emoji: "🍕", keywords: ["pizza", "focaccia", "flammkuchen", "calzone", "pizze"]),
        .init(emoji: "🍝", keywords: ["pasta", "spaghetti", "linguine", "pappardelle", "tagliatelle", "penne", "macaroni", "lasagne", "nudeln", "pates", "fideos"]),
        .init(emoji: "🥙", keywords: ["falafel", "shawarma", "shoarma", "doner", "durum"]),
        .init(emoji: "🥗", keywords: ["salad", "salade", "gado", "salat", "ensalada"]),
        .init(emoji: "🥔", keywords: ["potato", "aardappel", "stamppot", "rosti", "latke", "puree", "hutspot", "boerenkool", "kartoffel", "kartoffeln", "pomme de terre", "pommes de terre", "patata", "patatas", "papas"]),
        .init(emoji: "🍟", keywords: ["fries", "friet", "patat", "frites", "pommes"]),
        .init(emoji: "🥩", keywords: ["beef", "pork", "vlees", "steak", "biefstuk", "roast", "entrecote", "varken", "rind", "rindfleisch", "schwein", "schweinefleisch", "boeuf", "porc", "carne", "cerdo", "ternera", "filete"]),
        .init(emoji: "🐟", keywords: ["fish", "vis", "zalm", "salmon", "kibbeling", "forel", "kabeljauw", "cod", "zeebaars", "roodbaars", "tonijn", "tuna", "fisch", "poisson", "pescado", "lachs", "saumon", "kabeljau", "merluza"]),
        .init(emoji: "🌶️", keywords: ["chilli", "chili", "spicy", "pittig", "sambal"]),
        .init(emoji: "🌭", keywords: ["hotdog", "sausage", "worst", "braadworst", "bratwurst", "saucisse", "salchicha"]),
        .init(emoji: "🍗", keywords: ["chicken", "kip", "kalkoen", "turkey", "huhn", "hahnchen", "poulet", "pollo", "hanchen"]),
        .init(emoji: "🥘", keywords: ["stew", "stoof", "goulash", "paella", "hachee", "tajine", "eintopf", "ragout", "guiso", "estofado", "cocido"]),
        .init(emoji: "🍚", keywords: ["rice", "rijst", "pokebowl", "nasi", "risotto", "reis", "riz", "arroz"]),
        .init(emoji: "🍲", keywords: ["soup", "soep", "reshteh", "bibimbap", "gazpacho", "tom kha kai", "bouillon", "suppe", "soupe", "sopa", "eintopf", "caldo"]),
        .init(emoji: "🥓", keywords: ["bacon", "spek", "carbonara"]),
        .init(emoji: "🫓", keywords: ["flat bread", "platbrood", "okonomiyaki", "naan", "pita"]),
        .init(emoji: "🌮", keywords: ["taco", "quesadilla", "nacho"]),
        .init(emoji: "🍛", keywords: ["curry", "tonkatsu", "massaman"]),
        .init(emoji: "🦐", keywords: ["shrimp", "garnaal", "garnalen", "ebi", "scampi"]),
        .init(emoji: "🫘", keywords: ["bean", "boon", "bonen", "linzen", "lentil"]),
        .init(emoji: "🫛", keywords: ["french beans", "sperziebonen", "edamame", "peultjes", "doperwt"]),
        .init(emoji: "🧑‍🍳", keywords: ["restaurant", "uiteten", "afhalen", "takeaway"]),
        .init(emoji: "🥬", keywords: ["kale", "kool", "spinazie", "andijvie", "spitskool", "kohl", "spinat", "epinards", "espinacas"]),
        .init(emoji: "🍆", keywords: ["aubergine", "melanzane", "eggplant"]),
        .init(emoji: "🥦", keywords: ["broccoli", "broccolini", "brokkoli", "brocoli"]),
        .init(emoji: "🫑", keywords: ["bell pepper", "paprika"]),
        .init(emoji: "🥑", keywords: ["avocado", "guacamole"]),
        .init(emoji: "🥥", keywords: ["coconut", "kokos"]),
        .init(emoji: "🍅", keywords: ["tomato", "tomaat", "tomaten"]),
        .init(emoji: "🧅", keywords: ["onion", "uien", "sjalot"]),
        .init(emoji: "🥕", keywords: ["carrot", "wortel", "karotte", "karotten", "mohre", "carotte", "zanahoria"]),
        .init(emoji: "🧀", keywords: ["cheese", "kaas", "paneer", "mozzarella", "halloumi", "burrata", "fondue", "kase", "fromage", "queso"]),
        .init(emoji: "🌽", keywords: ["corn", "mais", "polenta"]),
        .init(emoji: "🥟", keywords: ["gyoza", "dumpling", "pierogi", "gnocchi", "ravioli", "empanada", "tortellini"]),
        .init(emoji: "🥞", keywords: ["pancakes", "pannenkoeken", "poffertjes"]),
        .init(emoji: "🧇", keywords: ["waffles", "wafels"]),
        .init(emoji: "🥧", keywords: ["pie", "quiche", "hartige taart"]),
        .init(emoji: "🔥", keywords: ["bbq", "barbeque", "barbecue", "teppanyaki", "gourmet", "wok", "grill"]),
        .init(emoji: "🍄‍🟫", keywords: ["mushroom", "paddestoel", "paddenstoel", "champignons", "zwammen", "pilz", "pilze", "champignon", "champinones", "setas"]),
        .init(emoji: "🧈", keywords: ["butter", "boter"]),
        .init(emoji: "🌱", keywords: ["basil", "herbs", "kruiden", "basilicum"]),
        .init(emoji: "🍞", keywords: ["bread", "brood", "tosti", "brot", "pain", "brotchen"]),
        .init(emoji: "🥠", keywords: ["samosa"]),
        .init(emoji: "🥯", keywords: ["buns", "bagel", "broodje"]),
        .init(emoji: "🍖", keywords: ["ribs", "spareribs"]),
        .init(emoji: "🍜", keywords: ["ramen", "noodles", "noedels", "mie", "pho", "bami"]),
        .init(emoji: "🍥", keywords: ["chashu"]),
        .init(emoji: "🍱", keywords: ["bento"]),
        .init(emoji: "🇮🇹", keywords: ["cannelloni"]),
        .init(emoji: "🍠", keywords: ["beet", "biet", "zoete aardappel"]),
        .init(emoji: "🥚", keywords: ["omelet", "omelette", "frittata", "eieren", "eier", "oeuf", "oeufs", "huevo", "huevos"]),
        .init(emoji: "🥡", keywords: ["take-out", "takeout", "chinees", "chinese"]),
        .init(emoji: "🧆", keywords: ["meatball", "gehaktbal", "gehakt", "kofte", "frikadelle", "boulette", "albondigas"]),
        .init(emoji: "🥒", keywords: ["cucumber", "komkommer", "courgette", "zucchini"]),
        .init(emoji: "🍢", keywords: ["souvlaki", "kebab", "skewer", "sate", "spies"]),
        .init(emoji: "🌿", keywords: ["asperges", "asparagus"]),
        .init(emoji: "🍰", keywords: ["taart", "cake"]),
        .init(emoji: "🥜", keywords: ["peanut", "pinda", "satesaus"]),
    ]

    /// De gegenereerde laag, ontleed bij eerste gebruik.
    static let generated: [EmojiKeywords] = parse(EmojiCatalogData.packed)

    /// Beide lagen achter elkaar. De volgorde bepaalt wie wint bij gelijke score,
    /// dus handmatige mappings staan vooraan.
    static let all: [EmojiKeywords] = curated + generated

    /// Elk trefwoord dat in de catalogus voorkomt. Gebruikt om te zien of een
    /// getypt woord op zichzelf al een bekend begrip is.
    static let allKeywords: Set<String> = Set(all.flatMap(\.keywords))

    /// Alle emoji die als suggestie kunnen voorkomen, zonder dubbele.
    static let allEmoji: [String] = {
        var seen = Set<String>()
        return all.map(\.emoji).filter { seen.insert($0).inserted }
    }()

    private static func parse(_ packed: String) -> [EmojiKeywords] {
        packed.split(separator: ";").compactMap { entry in
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            let keywords = parts[1].split(separator: ",").map(String.init)
            guard !keywords.isEmpty else { return nil }
            return EmojiKeywords(emoji: String(parts[0]), keywords: keywords)
        }
    }
}
