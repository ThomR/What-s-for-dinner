import Foundation

/// Kiest emoji bij de naam van een gerecht.
///
/// Volledig lokaal en zonder netwerk: de app belooft in de privacyverklaring dat
/// er niets van het toestel af gaat, en de namen van jullie maaltijden vallen
/// daaronder. Zie `EmojiIntelligence` voor de optionele extra laag op toestellen
/// met Apple Intelligence — ook die rekent op het toestel zelf.
enum EmojiSuggester {

    /// Hoeveel emoji er hoogstens naast een gerecht komen te staan.
    static let maximumEmoji = 3

    /// De emoji voor een gerechtnaam. Altijd hetzelfde antwoord voor dezelfde
    /// invoer — de oude versie liep over een `Dictionary` en kon per keer iets
    /// anders teruggeven.
    static func suggest(for name: String, limit: Int = maximumEmoji) -> String {
        let matches = rankedMatches(for: name)
        guard !matches.isEmpty else { return Emoji.fallback }
        return matches.prefix(limit).map(\.emoji).joined(separator: " ")
    }

    /// Of de suggestie niet meer was dan een gok. Bepaalt of het de moeite is om
    /// het taalmodel nog te raadplegen.
    static func isUncertain(_ emoji: String) -> Bool {
        emoji == Emoji.fallback || emoji.isEmpty
    }

    // MARK: - Zoeken

    struct Match: Equatable {
        let emoji: String
        let score: Int
        /// Positie in de catalogus, zodat gelijke scores een vaste volgorde hebben.
        let rank: Int
    }

    static func rankedMatches(for name: String) -> [Match] {
        let haystack = normalise(name)
        guard !haystack.isEmpty else { return [] }
        let tokens = haystack.split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard !tokens.isEmpty else { return [] }

        // Woorden die op zichzelf al een bekend begrip zijn, matchen niet meer
        // op woorddelen. Anders levert "pierogi" naast het deegpakketje ook de
        // taart op, omdat het woord toevallig met "pie" begint.
        let completeWords = Set(tokens.filter(EmojiCatalog.allKeywords.contains))

        var best: [String: Match] = [:]
        for (index, entry) in EmojiCatalog.all.enumerated() {
            // Handmatige mappings winnen het altijd van de gegenereerde laag,
            // ook als een gegenereerd trefwoord toevallig langer is.
            let bonus = index < EmojiCatalog.curated.count ? 100 : 0
            var entryScore = 0
            for keyword in entry.keywords {
                entryScore = max(entryScore, score(
                    keyword: keyword,
                    tokens: tokens,
                    haystack: haystack,
                    completeWords: completeWords
                ))
            }
            guard entryScore > 0 else { continue }
            let match = Match(emoji: entry.emoji, score: entryScore + bonus, rank: index)
            if let existing = best[entry.emoji], existing.score >= match.score { continue }
            best[entry.emoji] = match
        }

        let ranked = best.values.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.rank < $1.rank
        }

        // Is er een handmatige treffer, dan tellen de gegenereerde niet meer mee.
        // Die laatste laag is een vangnet voor onbekende gerechten, geen
        // aanvulling: zonder deze regel kreeg "pizza" er een paddenstoel bij en
        // "pasta" een koekje, alleen omdat er nog plek over was voor drie emoji.
        let isCurated = { (match: Match) in match.rank < EmojiCatalog.curated.count }
        if ranked.first.map(isCurated) == true {
            return ranked.filter(isCurated)
        }
        return ranked
    }

    /// Hoe goed één trefwoord op de naam past.
    ///
    /// Losse woorden tellen zwaarder dan delen van woorden, en een langer
    /// trefwoord is specifieker: "zoete aardappel" hoort te winnen van "aardappel".
    private static func score(keyword: String, tokens: [String], haystack: String, completeWords: Set<String>) -> Int {
        // Trefwoorden van meerdere woorden zoeken we in de hele naam.
        if keyword.contains(" ") {
            return haystack.contains(keyword) ? 40 + keyword.count : 0
        }

        var best = 0
        for token in tokens {
            if token == keyword {
                best = max(best, 40 + keyword.count)
                continue
            }
            // Een woord dat zelf een begrip is, wordt niet ook nog in stukken
            // geknipt.
            if completeWords.contains(token) { continue }

            if keyword.count >= 3, token.hasPrefix(keyword) {
                // Nederlandse samenstellingen: "kipfilet" begint met "kip".
                best = max(best, 20 + keyword.count)
            } else if keyword.count >= 4, token.hasSuffix(keyword) {
                // "tomatensoep" eindigt op "soep". Vier tekens minimaal, want
                // korte staarten matchen te makkelijk per ongeluk.
                best = max(best, 20 + keyword.count)
            }
        }
        return best
    }

    /// Kleine letters, accenten weg. Zo vindt "rosti" ook "rösti" en andersom.
    static func normalise(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
    }
}
