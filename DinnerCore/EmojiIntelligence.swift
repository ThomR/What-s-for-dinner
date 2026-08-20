import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Vraagt het taalmodel van het toestel om een emoji voor gerechten die de
/// woordenlijst niet kent.
///
/// Draait volledig op het toestel (Apple Intelligence) — er gaat niets naar een
/// server, dus de privacybelofte van de app blijft overeind. Op toestellen zonder
/// Apple Intelligence bestaat deze laag simpelweg niet en blijft het bij
/// `EmojiSuggester`.
enum EmojiIntelligence {

    /// Of het model nu bruikbaar is. Onwaar op oudere toestellen, met Apple
    /// Intelligence uit, of terwijl het model nog gedownload wordt.
    static var isAvailable: Bool {
        #if canImport(FoundationModels) && os(iOS)
        guard #available(iOS 26, *) else { return false }
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
    }

    /// Een emoji voor deze gerechtnaam, of `nil` als het model niets bruikbaars
    /// oplevert. Nooit een fout naar boven: dit is een extraatje, geen vereiste.
    static func suggest(for name: String) async -> String? {
        #if canImport(FoundationModels) && os(iOS)
        guard #available(iOS 26, *), isAvailable else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Dish: \(trimmed)",
                generating: EmojiChoice.self
            )
            let emoji = response.content.emoji
            // Het model mag alleen uit de catalogus kiezen, maar controleer het
            // alsnog: een emoji die de app niet kent hoort niet in de lijst.
            guard EmojiCatalog.allEmoji.contains(emoji) else {
                Log.emoji.info("Model gaf een onbekende emoji terug, genegeerd")
                return nil
            }
            return emoji
        } catch {
            Log.emoji.info("Model niet gebruikt: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        #else
        return nil
        #endif
    }

    private static let instructions = """
        You match the name of a dinner dish to a single food emoji.
        The name may be in Dutch or English and may be a brand, a regional dish, \
        or a household nickname for a meal.
        Pick the emoji that best shows the main ingredient or the type of dish.
        Answer with one emoji from the allowed list and nothing else.
        """
}

#if canImport(FoundationModels) && os(iOS)
@available(iOS 26, *)
@Generable
private struct EmojiChoice {
    @Guide(description: "The single best matching food emoji for this dish", .anyOf(EmojiCatalog.allEmoji))
    var emoji: String
}
#endif
