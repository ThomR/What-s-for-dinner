import Testing
import Foundation

/// Wat er in 2.0.2 misging tussen doorschuiven en iCloud. Twee klachten uit de
/// praktijk: de app bleef op woensdag staan en vinkte na een herstart een
/// gerecht te veel af, en de app crashte bij elke start tot je hem
/// herinstalleerde — waarna oude gerechten terug in de lijst stonden.
@MainActor
@Suite("Doorschuiven naast iCloud")
struct ICloudHerstelTests {

    final class Klok {
        var nu: Date
        init(_ nu: Date) { self.nu = nu }
    }

    private func kaart(_ dishes: [Dish]) -> [UUID: Dish] {
        Dictionary(uniqueKeysWithValues: dishes.map { ($0.id, $0) })
    }

    private func dag(_ dag: Int) -> Date {
        testCalendar.startOfDay(for: datum(2026, 11, dag))
    }

    // MARK: - Een oude volgorde uit iCloud

    @Test("Een oude volgorde na het doorschuiven zet het gerecht niet op gisteren")
    func oudeVolgordeNaDoorschuiven() {
        let wo = gerecht("Woensdag"), don = gerecht("Donderdag"), vr = gerecht("Vrijdag")

        // Donderdag 12 november: dit toestel heeft al doorgeschoven.
        let lokaal = PlanSchedule.advanced(
            MealPlan(dishes: [wo, don, vr], anchorDate: dag(11)),
            to: datum(2026, 11, 12), calendar: testCalendar, autoAdvance: true
        )

        // Dan komt het plan-record van woensdagavond binnen.
        let samengevoegd = PlanProjection.rebuild(
            dishes: kaart(lokaal.dishes),
            order: [wo.id, don.id, vr.id],
            anchorDate: dag(11),
            log: PlanProjection.byID(lokaal.log),
            calendar: testCalendar
        )

        #expect(samengevoegd.dishes.map(\.name) == ["Donderdag", "Vrijdag"])
        #expect(samengevoegd.anchorDate == dag(12))

        // En na een herstart is er niets extra afgevinkt.
        let herstart = PlanSchedule.advanced(samengevoegd, to: datum(2026, 11, 12, uur: 18), calendar: testCalendar, autoAdvance: true)
        #expect(herstart.log.map(\.name) == ["Woensdag"])
    }

    @Test("Een vooruit gegeten gerecht verderop schuift het anker niet op")
    func vooruitGegetenVerderop() {
        let wo = gerecht("Woensdag"), don = gerecht("Donderdag"), vr = gerecht("Vrijdag")
        let vooruit = ServedMeal(dish: vr, servedOn: dag(10))

        let plan = PlanProjection.rebuild(
            dishes: kaart([wo, don]),
            order: [wo.id, vr.id, don.id],
            anchorDate: dag(11),
            log: [vr.id: vooruit],
            calendar: testCalendar
        )
        #expect(plan.anchorDate == dag(11))
    }

    @Test("Een wijziging van gisteren wordt bij binnenkomst naar vandaag geschoven")
    func binnenkomstVanGisteren() {
        let klok = Klok(datum(2026, 11, 12))
        let opslag = DishStore(appGroup: "test.herstel.\(UUID().uuidString)", containerURL: tijdelijkeMap())
        opslag.save(planning(vanaf: datum(2026, 11, 12), "Donderdag", "Vrijdag"))
        let winkel = PlanStore(store: opslag, calendar: testCalendar, now: { klok.nu }, autoAdvance: { true })

        // Je partner heeft de app sinds woensdag niet geopend en voegt iets toe;
        // CloudSync schrijft dat zo naar schijf.
        opslag.save(planning(vanaf: datum(2026, 11, 11), "Woensdag", "Donderdag", "Vrijdag"))
        winkel.adoptRemoteChanges()

        #expect(winkel.scheduled.first?.dish.name == "Donderdag")
        #expect(winkel.scheduled.first?.date == dag(12))
    }

    // MARK: - Dubbele ids

    @Test("Een teruggekeerd gegeten gerecht verdwijnt uit de wachtrij")
    func zombieVerdwijnt() {
        let wo = gerecht("Woensdag"), vr = gerecht("Vrijdag")
        let plan = MealPlan(
            dishes: [vr, wo],
            anchorDate: dag(13),
            log: [ServedMeal(dish: wo, servedOn: dag(11))]
        ).normalized()

        #expect(plan.dishes.map(\.name) == ["Vrijdag"])
        #expect(plan.log.map(\.name) == ["Woensdag"])
    }

    @Test("Een gerecht dat na het eten is teruggezet blijft in de wachtrij")
    func teruggezetBlijft() {
        let wo = gerecht("Woensdag")
        let terug = ServedMeal(dish: wo, servedOn: dag(11)).restored(at: datum(2026, 11, 12, uur: 20))
        let plan = MealPlan(
            dishes: [terug],
            anchorDate: dag(13),
            log: [ServedMeal(dish: wo, servedOn: dag(11))]
        ).normalized()

        #expect(plan.dishes.map(\.name) == ["Woensdag"])
        #expect(plan.log.isEmpty)
    }

    @Test("Twee logregels met één id worden er één")
    func dubbeleLogregel() {
        let wo = gerecht("Woensdag")
        let plan = MealPlan(
            dishes: [],
            anchorDate: dag(13),
            log: [ServedMeal(dish: wo, servedOn: dag(4)), ServedMeal(dish: wo, servedOn: dag(11))]
        ).normalized()

        #expect(plan.log.count == 1)
        #expect(plan.log.first?.servedOn == dag(11))
    }

    @Test("Wijzigingen bepalen crasht niet op een dubbele id")
    func wijzigingenMetDubbeleId() {
        let wo = gerecht("Woensdag")
        let kapot = MealPlan(
            dishes: [wo, wo],
            anchorDate: dag(11),
            log: [ServedMeal(dish: wo, servedOn: dag(4)), ServedMeal(dish: wo, servedOn: dag(11))]
        )
        _ = PlanProjection.changes(from: kapot, to: kapot.normalized())
    }

    @Test("Een planning met dubbele ids op schijf herstelt zich bij het opstarten")
    func herstelBijOpstarten() {
        let klok = Klok(datum(2026, 11, 16))
        let wo = gerecht("Woensdag"), vr = gerecht("Vrijdag")
        let opslag = DishStore(appGroup: "test.herstel.\(UUID().uuidString)", containerURL: tijdelijkeMap())
        // Zoals de telefoon na herinstalleren en een paar dagen gebruik eruitzag.
        opslag.save(MealPlan(
            dishes: [vr, wo],
            anchorDate: dag(16),
            log: [ServedMeal(dish: wo, servedOn: dag(11)), ServedMeal(dish: wo, servedOn: dag(11))]
        ))

        let winkel = PlanStore(store: opslag, calendar: testCalendar, now: { klok.nu }, autoAdvance: { true })

        #expect(winkel.plan.dishes.map(\.name) == ["Vrijdag"])
        #expect(winkel.plan.log.count == 1)
        opslag.invalidateCache()
        #expect(opslag.load() == winkel.plan)
    }

    @Test("Afvinken zet een gerecht nooit twee keer in het logboek")
    func afvinkenZonderDubbel() {
        let wo = gerecht("Woensdag")
        var plan = MealPlan(dishes: [wo], anchorDate: dag(11), log: [ServedMeal(dish: wo, servedOn: dag(4))])
        plan = PlanSchedule.advanced(plan, to: datum(2026, 11, 12), calendar: testCalendar, autoAdvance: true)
        #expect(plan.log.count == 1)

        plan = MealPlan(dishes: [wo], anchorDate: dag(11), log: [ServedMeal(dish: wo, servedOn: dag(4))])
        plan = PlanSchedule.serving(plan, dishID: wo.id, at: datum(2026, 11, 11), calendar: testCalendar, autoAdvance: true)
        #expect(plan.log.count == 1)
    }
}
