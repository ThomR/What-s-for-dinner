import Testing
import Foundation

/// Wat er gebeurt als je zelf afstreept terwijl "dagelijks automatisch
/// afvinken" aan staat. In 2.0 kwamen daardoor twee gerechten op dezelfde dag in
/// het logboek terecht (zo 6 sep: Sunday Roast én Tonkatsu).
@MainActor
@Suite("Zelf afstrepen naast automatisch afvinken")
struct AfstreepTests {

    /// Een klok die de test zelf verzet.
    final class Klok {
        var nu: Date
        init(_ nu: Date) { self.nu = nu }
    }

    private func winkel(_ klok: Klok, _ namen: String...) -> PlanStore {
        let opslag = DishStore(appGroup: "test.afstrepen.\(UUID().uuidString)", containerURL: tijdelijkeMap())
        opslag.save(MealPlan(
            dishes: namen.map { gerecht($0) },
            anchorDate: testCalendar.startOfDay(for: klok.nu),
            log: []
        ))
        return PlanStore(store: opslag, calendar: testCalendar, now: { klok.nu }, autoAdvance: { true })
    }

    private func logboek(_ winkel: PlanStore) -> [String] {
        winkel.log
            .sorted { $0.servedOn < $1.servedOn }
            .map { "\($0.name) \(testCalendar.component(.day, from: $0.servedOn))" }
    }

    @Test("Vandaag afstrepen trekt morgen niet naar vandaag")
    func zondagavond() {
        // Zondag 6 september, 's avonds na het eten.
        let klok = Klok(datum(2026, 9, 6, uur: 20))
        let winkel = winkel(klok, "Sunday Roast", "Tonkatsu", "Ravioli")

        winkel.serve(winkel.plan.dishes[0])
        // Tonkatsu is nog steeds voor maandag.
        #expect(winkel.scheduled.first?.dish.name == "Tonkatsu")
        #expect(winkel.scheduled.first?.date == testCalendar.startOfDay(for: datum(2026, 9, 7)))

        // Middernacht voorbij.
        klok.nu = datum(2026, 9, 7, uur: 9)
        winkel.refresh()

        // Op maandag is Tonkatsu nog niet gegeten; dat gebeurt pas dinsdag.
        #expect(logboek(winkel) == ["Sunday Roast 6"])
        #expect(winkel.scheduled.first?.dish.name == "Tonkatsu")

        klok.nu = datum(2026, 9, 8, uur: 9)
        winkel.refresh()
        #expect(logboek(winkel) == ["Sunday Roast 6", "Tonkatsu 7"])
    }

    @Test("Een app die om middernacht openstaat streept precies één gerecht af")
    func middernacht() {
        let klok = Klok(datum(2026, 9, 6, uur: 23))
        let winkel = winkel(klok, "Sunday Roast", "Tonkatsu", "Ravioli")

        klok.nu = datum(2026, 9, 7, uur: 0)
        winkel.refresh()
        winkel.refresh()
        klok.nu = datum(2026, 9, 7, uur: 1)
        winkel.refresh()

        #expect(logboek(winkel) == ["Sunday Roast 6"])
    }

    @Test("Twee gerechten op één avond afstrepen houdt de rest op hun dag")
    func tweeOpEenAvond() {
        let klok = Klok(datum(2026, 9, 6, uur: 20))
        let winkel = winkel(klok, "Sunday Roast", "Tonkatsu", "Ravioli")

        winkel.serve(winkel.plan.dishes[0])
        winkel.serve(winkel.plan.dishes[0])

        // Allebei vandaag gegeten, dus allebei vandaag in het logboek; Ravioli
        // blijft op zijn eigen dag staan, dinsdag.
        #expect(logboek(winkel) == ["Sunday Roast 6", "Tonkatsu 6"])
        #expect(winkel.scheduled.first?.date == testCalendar.startOfDay(for: datum(2026, 9, 8)))
    }

    @Test("Een gerecht schrappen laat het volgende wél opschuiven")
    func schrappen() {
        // Schrappen is iets anders dan eten: "dat eten we toch niet" betekent
        // dat het volgende gerecht zijn plek inneemt.
        let klok = Klok(datum(2026, 9, 6, uur: 17))
        let winkel = winkel(klok, "Sunday Roast", "Tonkatsu", "Ravioli")

        winkel.remove(winkel.plan.dishes[0])
        #expect(winkel.scheduled.first?.dish.name == "Tonkatsu")
        #expect(winkel.scheduled.first?.date == testCalendar.startOfDay(for: datum(2026, 9, 6)))
        #expect(winkel.log.isEmpty)
    }

    @Test("Een nieuw gerecht in een lege lijst na het eten van vandaag is voor morgen")
    func nieuwGerechtNaAfstrepen() {
        let klok = Klok(datum(2026, 9, 6, uur: 20))
        let winkel = winkel(klok, "Sunday Roast")

        winkel.serve(winkel.plan.dishes[0])
        winkel.add(name: "Pasta")

        #expect(winkel.scheduled.first?.date == testCalendar.startOfDay(for: datum(2026, 9, 7)))
    }
}
