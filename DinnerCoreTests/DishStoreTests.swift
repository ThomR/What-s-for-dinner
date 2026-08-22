import Testing
import Foundation

/// De opslag zelf, inclusief de overstap vanaf versie 1.
///
/// Elke test krijgt een eigen map en een eigen `UserDefaults`-suite, zodat ze
/// elkaar niet in de weg zitten en er niets van het echte toestel wordt geraakt.
@Suite("Opslag van de planning")
struct DishStoreTests {

    private func nieuweSuite() -> String { "test.dinner.\(UUID().uuidString)" }

    @Test("Wat je opslaat komt er weer uit, ook na opnieuw openen")
    func rondreisOverSchijf() {
        let map = tijdelijkeMap()
        let suite = nieuweSuite()
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")

        DishStore(appGroup: suite, containerURL: map).save(plan)

        // Een tweede store staat voor een volgende start van de app of voor de
        // widget, die een eigen proces is en dus een eigen cache heeft.
        let opnieuw = DishStore(appGroup: suite, containerURL: map).load()
        #expect(opnieuw == plan)
    }

    @Test("Zonder eerdere gegevens begint de planning leeg")
    func legeStart() {
        let plan = DishStore(appGroup: nieuweSuite(), containerURL: tijdelijkeMap()).load()
        #expect(plan.dishes.isEmpty)
        #expect(plan.log.isEmpty)
    }

    // Loopt de migratie opnieuw vast, dan hangt de test in plaats van te falen —
    // vandaar de tijdslimiet. De oorzaak was een `queue.sync` binnen een
    // `queue.sync` op dezelfde seriële queue.
    @Test("Een planning uit versie 1 wordt overgenomen zonder vast te lopen", .timeLimit(.minutes(1)))
    func migratieVanuitVersie1() throws {
        let map = tijdelijkeMap()
        let suite = nieuweSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let dishes = [versie1Gerecht("Pizza", emoji: "🍕"), versie1Gerecht("Soep", emoji: "🍲")]
        let completed = [versie1Gerecht("Pasta", emoji: "🍝", voltooidOp: datum(2026, 8, 15))]
        defaults.set(try JSONSerialization.data(withJSONObject: dishes), forKey: "dishes")
        defaults.set(try JSONSerialization.data(withJSONObject: completed), forKey: "completedDishes")

        let plan = DishStore(appGroup: suite, containerURL: map).load()
        #expect(plan.dishes.map(\.name) == ["Pizza", "Soep"])
        #expect(plan.dishes.map(\.emoji) == ["🍕", "🍲"])
        #expect(plan.log.map(\.name) == ["Pasta"])
    }

    @Test("De omgezette planning staat daarna ook op schijf", .timeLimit(.minutes(1)))
    func migratieWordtBewaard() throws {
        let map = tijdelijkeMap()
        let suite = nieuweSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONSerialization.data(withJSONObject: [versie1Gerecht("Pizza")]), forKey: "dishes")

        _ = DishStore(appGroup: suite, containerURL: map).load()

        // Tweede store, verse cache: die moet het bestand vinden dat de migratie
        // heeft weggeschreven, niet opnieuw hoeven migreren.
        defaults.removeObject(forKey: "dishes")
        let opnieuw = DishStore(appGroup: suite, containerURL: map).load()
        #expect(opnieuw.dishes.map(\.name) == ["Pizza"])
    }

    @Test("De Watch neemt zijn eigen oude sleutel over", .timeLimit(.minutes(1)))
    func migratieVanDeWatch() throws {
        let map = tijdelijkeMap()
        let suite = nieuweSuite()
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONSerialization.data(withJSONObject: [versie1Gerecht("Zalmfilet")]), forKey: "watchDishes")

        let plan = DishStore(appGroup: suite, containerURL: map).load()
        #expect(plan.dishes.map(\.name) == ["Zalmfilet"])
    }

    @Test("Een onleesbaar bestand levert een lege planning op, geen crash")
    func kapotBestand() throws {
        let map = tijdelijkeMap()
        try Data("dit is geen json".utf8).write(to: map.appendingPathComponent("mealplan.json"))

        let plan = DishStore(appGroup: nieuweSuite(), containerURL: map).load()
        #expect(plan.dishes.isEmpty)
    }

    @Test("Na het weggooien van de cache wordt er opnieuw van schijf gelezen")
    func cacheVerversen() {
        let map = tijdelijkeMap()
        let suite = nieuweSuite()
        let lezer = DishStore(appGroup: suite, containerURL: map)
        #expect(lezer.load().dishes.isEmpty)

        // Een ander proces — in de praktijk de app — schrijft er iets in.
        DishStore(appGroup: suite, containerURL: map).save(planning(vanaf: datum(2026, 8, 20), "Pizza"))

        #expect(lezer.load().dishes.isEmpty, "zonder verversen hoort de cache te blijven staan")
        lezer.invalidateCache()
        #expect(lezer.load().dishes.map(\.name) == ["Pizza"])
    }
}
