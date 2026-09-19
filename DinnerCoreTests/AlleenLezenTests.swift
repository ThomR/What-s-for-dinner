import Testing
import Foundation

/// Wie in de lijst van een ander alleen mag kijken, mag er niets aan veranderen.
/// De knoppen zijn dan verborgen; dit test de vangrail eronder, want een
/// wijziging die toch doorglipt zou CloudKit weigeren en de lijst laten afwijken.
@MainActor
@Suite("Alleen bekijken")
struct AlleenLezenTests {

    private func winkel(alleenLezen: Bool) -> PlanStore {
        let opslag = DishStore(appGroup: "test.lezen.\(UUID().uuidString)", containerURL: tijdelijkeMap())
        opslag.save(planning(vanaf: datum(2026, 9, 6), "Pizza", "Soep"))
        return PlanStore(
            store: opslag,
            calendar: testCalendar,
            now: { datum(2026, 9, 6, uur: 18) },
            autoAdvance: { true },
            sharing: { (shared: true, readOnly: alleenLezen) }
        )
    }

    @Test("Niets toevoegen, hernoemen, afstrepen, schrappen of verslepen")
    func niksVeranderen() {
        let winkel = winkel(alleenLezen: true)
        let voor = winkel.plan

        winkel.add(name: "Pasta")
        winkel.rename(winkel.plan.dishes[0], to: "Calzone")
        winkel.serve(winkel.plan.dishes[0])
        winkel.remove(winkel.plan.dishes[0])
        winkel.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        winkel.clearQueue()
        winkel.clearLog()

        #expect(winkel.plan == voor)
        #expect(winkel.isReadOnly)
    }

    @Test("Mag je wijzigen, dan werkt alles gewoon")
    func welVeranderen() {
        let winkel = winkel(alleenLezen: false)
        winkel.add(name: "Pasta")
        #expect(winkel.plan.dishes.map(\.name) == ["Pizza", "Soep", "Pasta"])
        #expect(winkel.isSharedList)
        #expect(!winkel.isReadOnly)
    }
}
