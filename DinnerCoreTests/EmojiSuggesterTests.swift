import Testing
import Foundation

/// De emoji-herkenning. De oude versie liep over een `Dictionary` en kon per
/// keer een andere emoji kiezen voor hetzelfde gerecht; dat mag niet terugkomen.
@Suite("Emoji bij een gerecht")
struct EmojiSuggesterTests {

    @Test("Dezelfde naam geeft altijd hetzelfde antwoord")
    func deterministisch() {
        // "wortel" en "prei" zitten allebei in de catalogus, dus hier moest de
        // oude versie kiezen — en dat deed hij elke keer anders.
        let namen = ["stamppot met worst en wortel", "pizza", "kip met rijst en broccoli"]
        for naam in namen {
            let antwoorden = Set((0..<25).map { _ in EmojiSuggester.suggest(for: naam) })
            #expect(antwoorden.count == 1, "\(naam) leverde \(antwoorden.count) verschillende uitkomsten")
        }
    }

    @Test("Een onbekend gerecht krijgt het standaardbord")
    func onbekend() {
        #expect(EmojiSuggester.suggest(for: "qwertyuiop") == Emoji.fallback)
        #expect(EmojiSuggester.suggest(for: "") == Emoji.fallback)
        #expect(EmojiSuggester.suggest(for: "   ") == Emoji.fallback)
    }

    @Test("Nederlandse samenstellingen worden herkend", arguments: [
        ("kipfilet", "🍗"),
        ("tomatensoep", "🍲"),
        ("zalmfilet", "🐟"),
        ("aardappelpuree", "🥔"),
        ("kipsate", "🍗"),
    ])
    func samenstellingen(naam: String, verwacht: String) {
        let emoji = EmojiSuggester.suggest(for: naam)
        #expect(emoji.contains(verwacht), "\(naam) gaf \(emoji)")
    }

    @Test("Handmatige mappings gaan voor op de gegenereerde lijst")
    func handmatigWint() {
        // "carbonara" staat nergens in de Unicode-data, maar wel in de eigen lijst.
        #expect(EmojiSuggester.suggest(for: "carbonara").contains("🥓"))
        // "uiteten" hoort bij de kok, niet bij een ui.
        #expect(EmojiSuggester.suggest(for: "uiteten").contains("🧑‍🍳"))
    }

    @Test("Accenten maken niet uit")
    func accenten() {
        #expect(EmojiSuggester.suggest(for: "rösti") == EmojiSuggester.suggest(for: "rosti"))
        #expect(EmojiSuggester.suggest(for: "RÖSTI") == EmojiSuggester.suggest(for: "rosti"))
    }

    @Test("Hoofdletters maken niet uit")
    func hoofdletters() {
        #expect(EmojiSuggester.suggest(for: "Pizza Margherita") == EmojiSuggester.suggest(for: "pizza margherita"))
    }

    @Test("Nooit meer dan drie emoji")
    func hoogstensDrie() {
        let emoji = EmojiSuggester.suggest(for: "kip met rijst, broccoli, wortel, ui en kaas")
        #expect(emoji.split(separator: " ").count <= EmojiSuggester.maximumEmoji)
    }

    @Test("Een langer trefwoord wint van een korter dat erin zit")
    func langsteTrefwoordWint() {
        // "zoete aardappel" is specifieker dan "aardappel".
        #expect(EmojiSuggester.suggest(for: "zoete aardappel").hasPrefix("🍠"))
    }

    @Test("Korte trefwoorden matchen niet zomaar midden in een woord")
    func geenToevalligeTreffers() {
        // "ui" is te kort om als deel van een woord mee te tellen; "buikspek"
        // mag geen ui opleveren. Spek wel.
        let emoji = EmojiSuggester.suggest(for: "buikspek")
        #expect(!emoji.contains("🧅"))
        #expect(emoji.contains("🥓"))
    }

    @Test("Losse woorden tellen zwaarder dan woorddelen")
    func heelWoordWint() {
        let matches = EmojiSuggester.rankedMatches(for: "soep")
        #expect(matches.first?.emoji == "🍲")
    }

    @Test("De catalogus bevat geen dubbele emoji in de handmatige laag")
    func geenDubbeleHandmatigeEmoji() {
        let emoji = EmojiCatalog.curated.map(\.emoji)
        #expect(Set(emoji).count == emoji.count)
    }

    @Test("Elk trefwoord in de handmatige laag is bruikbaar")
    func handmatigeTrefwoordenZijnSchoon() {
        for entry in EmojiCatalog.curated {
            for keyword in entry.keywords {
                #expect(keyword == keyword.lowercased(), "\(keyword) heeft hoofdletters")
                #expect(keyword.count >= 3, "\(keyword) is te kort om te matchen")
                #expect(!keyword.hasPrefix(" ") && !keyword.hasSuffix(" "), "\(keyword) heeft spaties aan de rand")
            }
            #expect(Set(entry.keywords).count == entry.keywords.count, "\(entry.emoji) heeft een dubbel trefwoord")
        }
    }

    @Test("De gegenereerde catalogus is geladen")
    func gegenereerdeCatalogus() {
        #expect(EmojiCatalog.generated.count > 50)
        #expect(EmojiCatalog.generated.allSatisfy { !$0.keywords.isEmpty })
    }

    @Test("Onzekerheid wordt herkend, zodat het taalmodel kan bijspringen")
    func onzekerheid() {
        #expect(EmojiSuggester.isUncertain(Emoji.fallback))
        #expect(EmojiSuggester.isUncertain(""))
        #expect(!EmojiSuggester.isUncertain("🍕"))
    }
}
