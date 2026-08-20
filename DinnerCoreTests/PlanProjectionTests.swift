import Testing
import Foundation

/// Het samenvoegen van wijzigingen die uit iCloud komen. De CloudKit-bedrading
/// zelf is hier niet te testen, maar dit is waar het mis kan gaan: twee mensen
/// die tegelijk iets veranderen.
@Suite("Samenvoegen van gedeelde wijzigingen")
struct PlanProjectionTests {

    private func kaart(_ dishes: [Dish]) -> [UUID: Dish] {
        Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
    }

    @Test("De opgeslagen volgorde wordt gevolgd")
    func volgordeWordtGevolgd() {
        let pizza = gerecht("Pizza")
        let soep = gerecht("Soep")
        let pasta = gerecht("Pasta")
        let plan = PlanProjection.rebuild(
            dishes: kaart([pizza, soep, pasta]),
            order: [pasta.id, pizza.id, soep.id],
            anchorDate: datum(2026, 8, 20),
            log: [:]
        )
        #expect(plan.dishes.map(\.name) == ["Pasta", "Pizza", "Soep"])
    }

    @Test("Een gerecht dat de ander net toevoegde raakt niet kwijt")
    func nieuwGerechtBlijftBehouden() {
        // De volgorde is nog van vóór de toevoeging; het nieuwe gerecht staat er
        // niet in. Het hoort achteraan te belanden, niet te verdwijnen.
        let pizza = gerecht("Pizza")
        let soep = gerecht("Soep")
        var nieuw = gerecht("Net toegevoegd")
        nieuw.addedAt = datum(2026, 8, 20)

        let plan = PlanProjection.rebuild(
            dishes: kaart([pizza, soep, nieuw]),
            order: [pizza.id, soep.id],
            anchorDate: datum(2026, 8, 20),
            log: [:]
        )
        #expect(plan.dishes.map(\.name) == ["Pizza", "Soep", "Net toegevoegd"])
    }

    @Test("Een volgorde die naar een verwijderd gerecht wijst levert geen gat op")
    func verwijderdGerechtInVolgorde() {
        let pizza = gerecht("Pizza")
        let weg = gerecht("Verwijderd")
        let plan = PlanProjection.rebuild(
            dishes: kaart([pizza]),
            order: [weg.id, pizza.id],
            anchorDate: datum(2026, 8, 20),
            log: [:]
        )
        #expect(plan.dishes.map(\.name) == ["Pizza"])
    }

    @Test("Een dubbele vermelding in de volgorde levert geen dubbel gerecht op")
    func dubbeleVermelding() {
        let pizza = gerecht("Pizza")
        let plan = PlanProjection.rebuild(
            dishes: kaart([pizza]),
            order: [pizza.id, pizza.id],
            anchorDate: datum(2026, 8, 20),
            log: [:]
        )
        #expect(plan.dishes.count == 1)
    }

    @Test("Twee tegelijk toegevoegde gerechten krijgen altijd dezelfde volgorde")
    func stabieleVolgordeBijGelijkeTijd() {
        // Zelfde tijdstempel: zonder tweede sleutel zou de uitkomst per apparaat
        // kunnen verschillen, en dan blijven de lijsten heen en weer schuiven.
        var a = gerecht("Aardappels")
        var b = gerecht("Bloemkool")
        a.addedAt = datum(2026, 8, 20)
        b.addedAt = datum(2026, 8, 20)

        let eerste = PlanProjection.rebuild(dishes: kaart([a, b]), order: [], anchorDate: datum(2026, 8, 20), log: [:])
        let tweede = PlanProjection.rebuild(dishes: kaart([b, a]), order: [], anchorDate: datum(2026, 8, 20), log: [:])
        #expect(eerste.dishes.map(\.id) == tweede.dishes.map(\.id))
    }

    @Test("Het logboek komt op datum te staan")
    func logboekOpDatum() {
        let oud = ServedMeal(dish: gerecht("Oud"), servedOn: datum(2026, 8, 10))
        let nieuw = ServedMeal(dish: gerecht("Nieuw"), servedOn: datum(2026, 8, 19))
        let plan = PlanProjection.rebuild(
            dishes: [:],
            order: [],
            anchorDate: datum(2026, 8, 20),
            log: [oud.id: oud, nieuw.id: nieuw]
        )
        #expect(plan.log.map(\.name) == ["Oud", "Nieuw"])
    }

    // MARK: - Wat er verstuurd moet worden

    @Test("Zonder wijziging valt er niets te versturen")
    func geenWijziging() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")
        #expect(PlanProjection.changes(from: plan, to: plan).isEmpty)
    }

    @Test("Een toegevoegd gerecht levert een wijziging én een nieuwe volgorde op")
    func toevoegen() {
        let oud = planning(vanaf: datum(2026, 8, 20), "Pizza")
        var nieuw = oud
        let extra = gerecht("Soep")
        nieuw.dishes.append(extra)

        let changes = PlanProjection.changes(from: oud, to: nieuw)
        #expect(changes.changedDishes == [extra.id])
        #expect(changes.removedDishes.isEmpty)
        #expect(changes.metadataChanged)
    }

    @Test("Een hernoemd gerecht verandert alleen dat gerecht")
    func hernoemen() {
        let oud = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")
        var nieuw = oud
        nieuw.dishes[1].name = "Tomatensoep"

        let changes = PlanProjection.changes(from: oud, to: nieuw)
        #expect(changes.changedDishes == [oud.dishes[1].id])
        #expect(!changes.metadataChanged)
    }

    @Test("Afstrepen verwijdert het gerecht en voegt een logregel toe")
    func afstrepen() {
        let oud = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")
        var nieuw = oud
        let weg = nieuw.dishes.removeFirst()
        nieuw.log.append(ServedMeal(dish: weg, servedOn: datum(2026, 8, 20)))

        let changes = PlanProjection.changes(from: oud, to: nieuw)
        #expect(changes.removedDishes == [weg.id])
        #expect(changes.changedMeals == [weg.id])
        #expect(changes.metadataChanged)
    }

    @Test("Alleen van volgorde wisselen stuurt geen gerechten opnieuw op")
    func alleenVolgorde() {
        let oud = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")
        var nieuw = oud
        nieuw.dishes.reverse()

        let changes = PlanProjection.changes(from: oud, to: nieuw)
        #expect(changes.changedDishes.isEmpty)
        #expect(changes.removedDishes.isEmpty)
        #expect(changes.metadataChanged)
    }

    @Test("Een planning is na omzetten naar records en terug ongewijzigd")
    func rondreisViaRecords() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep", "Pasta")
        let terug = PlanProjection.rebuild(
            dishes: kaart(plan.dishes),
            order: PlanProjection.order(of: plan),
            anchorDate: plan.anchorDate,
            log: [:]
        )
        #expect(terug == plan)
    }
}
