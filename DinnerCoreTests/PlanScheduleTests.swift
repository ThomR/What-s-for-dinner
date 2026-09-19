import Testing
import Foundation

/// De dagrekenkunde onder de planning. Dit is de laag die bepaalt wat de widget
/// en de Watch laten zien zonder dat de app draait, dus hier mag niets zweven.
@Suite("Planning en dagwissel")
struct PlanScheduleTests {

    // MARK: - Dagen tellen

    @Test("Dezelfde dag levert nul dagen op, ook bij een ander tijdstip")
    func zelfdeDag() {
        let dagen = PlanSchedule.elapsedDays(
            from: datum(2026, 8, 20, uur: 23),
            to: datum(2026, 8, 20, uur: 1),
            calendar: testCalendar
        )
        #expect(dagen == 0)
    }

    @Test("Een klok die terugloopt schuift de planning niet achteruit")
    func klokTerug() {
        let dagen = PlanSchedule.elapsedDays(
            from: datum(2026, 8, 20),
            to: datum(2026, 8, 17),
            calendar: testCalendar
        )
        #expect(dagen == 0)
    }

    @Test("De nacht waarin de zomertijd ingaat telt als één dag")
    func zomertijd() {
        // In Nederland gaat de klok in de nacht van 28 op 29 maart 2026 vooruit;
        // die dag is 23 uur lang. Een teller op basis van 86.400 seconden zou
        // hier de dagwissel missen.
        let dagen = PlanSchedule.elapsedDays(
            from: datum(2026, 3, 28, uur: 20),
            to: datum(2026, 3, 29, uur: 20),
            calendar: testCalendar
        )
        #expect(dagen == 1)
    }

    @Test("Over een maandgrens heen blijft het tellen kloppen")
    func maandgrens() {
        let dagen = PlanSchedule.elapsedDays(
            from: datum(2026, 1, 30),
            to: datum(2026, 2, 2),
            calendar: testCalendar
        )
        #expect(dagen == 3)
    }

    // MARK: - Wat er vandaag op tafel staat

    @Test("Na twee dagen is het derde gerecht aan de beurt")
    func gerechtVanVandaag() {
        let plan = planning(vanaf: datum(2026, 8, 17), "Pizza", "Soep", "Pasta")
        let vandaag = PlanSchedule.currentDish(
            in: plan, at: datum(2026, 8, 19), calendar: testCalendar, autoAdvance: true
        )
        #expect(vandaag?.name == "Pasta")
    }

    @Test("Zonder automatisch doorschuiven blijft het bovenste gerecht staan")
    func geenAutomatischDoorschuiven() {
        let plan = planning(vanaf: datum(2026, 8, 17), "Pizza", "Soep", "Pasta")
        let vandaag = PlanSchedule.currentDish(
            in: plan, at: datum(2026, 8, 19), calendar: testCalendar, autoAdvance: false
        )
        #expect(vandaag?.name == "Pizza")
    }

    @Test("Een lege wachtrij levert geen gerecht op in plaats van een crash")
    func legeWachtrij() {
        let plan = MealPlan(dishes: [], anchorDate: datum(2026, 8, 17), log: [])
        let vandaag = PlanSchedule.currentDish(
            in: plan, at: datum(2026, 8, 25), calendar: testCalendar, autoAdvance: true
        )
        #expect(vandaag == nil)
    }

    @Test("Een lijst die opraakt loopt niet verder achter")
    func lijstRaaktOp() {
        // Drie gerechten, tien dagen niets gedaan: er kunnen er maar drie
        // gegeten zijn, niet tien.
        let plan = planning(vanaf: datum(2026, 8, 10), "Pizza", "Soep", "Pasta")
        let aantal = PlanSchedule.servedCount(in: plan, at: datum(2026, 8, 20), calendar: testCalendar)
        #expect(aantal == 3)
    }

    // MARK: - Doorschuiven

    @Test("Verstreken dagen verhuizen naar het logboek met de juiste datum")
    func logboekKrijgtJuisteDatums() {
        let plan = planning(vanaf: datum(2026, 8, 17), "Pizza", "Soep", "Pasta")
        let nieuw = PlanSchedule.advanced(
            plan, to: datum(2026, 8, 19), calendar: testCalendar, autoAdvance: true
        )

        #expect(nieuw.dishes.map(\.name) == ["Pasta"])
        #expect(nieuw.log.count == 2)
        #expect(nieuw.log.first?.name == "Pizza")
        #expect(nieuw.log.first?.servedOn == testCalendar.startOfDay(for: datum(2026, 8, 17)))
        #expect(nieuw.log.last?.name == "Soep")
        #expect(nieuw.log.last?.servedOn == testCalendar.startOfDay(for: datum(2026, 8, 18)))
        // Het overgebleven gerecht is vandaag aan de beurt.
        #expect(nieuw.anchorDate == testCalendar.startOfDay(for: datum(2026, 8, 19)))
    }

    @Test("Twee keer doorschuiven op dezelfde dag verandert niets meer")
    func doorschuivenIsIdempotent() {
        let plan = planning(vanaf: datum(2026, 8, 17), "Pizza", "Soep", "Pasta")
        let nu = datum(2026, 8, 19)
        let eenmaal = PlanSchedule.advanced(plan, to: nu, calendar: testCalendar, autoAdvance: true)
        let tweemaal = PlanSchedule.advanced(eenmaal, to: nu, calendar: testCalendar, autoAdvance: true)
        #expect(eenmaal == tweemaal)
    }

    @Test("Een leeggelopen lijst begint vandaag opnieuw")
    func leeggelopenLijstAnkertVandaag() {
        // Twee gerechten, maar er zijn zes dagen voorbij. Het anker moet naar
        // vandaag, anders lijkt een nieuw gerecht vier dagen geleden gepland.
        let plan = planning(vanaf: datum(2026, 8, 14), "Pizza", "Soep")
        let nieuw = PlanSchedule.advanced(
            plan, to: datum(2026, 8, 20), calendar: testCalendar, autoAdvance: true
        )
        #expect(nieuw.dishes.isEmpty)
        #expect(nieuw.anchorDate == testCalendar.startOfDay(for: datum(2026, 8, 20)))
    }

    @Test("Zonder automatisch doorschuiven blijft de wachtrij intact")
    func handmatigModusRaaktNiets() {
        let plan = planning(vanaf: datum(2026, 8, 10), "Pizza", "Soep", "Pasta")
        let nieuw = PlanSchedule.advanced(
            plan, to: datum(2026, 8, 20), calendar: testCalendar, autoAdvance: false
        )
        #expect(nieuw.dishes.map(\.name) == ["Pizza", "Soep", "Pasta"])
        #expect(nieuw.log.isEmpty)
        // De daglabels moeten wel bij vandaag beginnen.
        #expect(nieuw.anchorDate == testCalendar.startOfDay(for: datum(2026, 8, 20)))
    }

    // Tot en met 2.0 werd een anker in de toekomst naar vandaag teruggezet. Dat
    // was fout: een anker op morgen betekent dat het gerecht van vandaag al
    // gegeten is, en terugzetten liet het volgende gerecht óók vandaag afstrepen.
    @Test("Een anker in de toekomst blijft staan: vandaag is al gegeten")
    func ankerInDeToekomst() {
        let plan = planning(vanaf: datum(2026, 8, 21), "Pizza", "Soep")
        let nieuw = PlanSchedule.advanced(
            plan, to: datum(2026, 8, 20), calendar: testCalendar, autoAdvance: true
        )
        #expect(nieuw.anchorDate == testCalendar.startOfDay(for: datum(2026, 8, 21)))
        #expect(nieuw.dishes.map(\.name) == ["Pizza", "Soep"])
        #expect(nieuw.log.isEmpty)
    }

    @Test("Doorschuiven over de zomertijd heen eet precies één gerecht")
    func doorschuivenOverZomertijd() {
        let plan = planning(vanaf: datum(2026, 3, 28), "Pizza", "Soep")
        let nieuw = PlanSchedule.advanced(
            plan, to: datum(2026, 3, 29), calendar: testCalendar, autoAdvance: true
        )
        #expect(nieuw.log.map(\.name) == ["Pizza"])
        #expect(nieuw.dishes.map(\.name) == ["Soep"])
    }

    // MARK: - Labels

    @Test("De dag van een positie in de wachtrij")
    func geplandeDatum() {
        let anker = datum(2026, 8, 17)
        let derde = PlanSchedule.plannedDate(offset: 2, anchorDate: anker, calendar: testCalendar)
        #expect(derde == testCalendar.startOfDay(for: datum(2026, 8, 19)))
    }

    @Test("Vandaag, morgen, een weekdag en daarna een datum")
    func daglabels() {
        let nu = datum(2026, 8, 20)
        #expect(PlanSchedule.dayLabel(for: datum(2026, 8, 20), at: nu, calendar: testCalendar) == .today)
        #expect(PlanSchedule.dayLabel(for: datum(2026, 8, 21), at: nu, calendar: testCalendar) == .tomorrow)
        // 20 augustus 2026 is een donderdag, dus 22 augustus is zaterdag (index 5).
        #expect(PlanSchedule.dayLabel(for: datum(2026, 8, 22), at: nu, calendar: testCalendar) == .weekday(5))
        // Een week vooruit zou dezelfde weekdagnaam opleveren; dan een datum.
        let ver = PlanSchedule.dayLabel(for: datum(2026, 8, 30), at: nu, calendar: testCalendar)
        #expect(ver == .date(testCalendar.startOfDay(for: datum(2026, 8, 30))))
    }

    @Test("Maandag is index 0 en zondag index 6")
    func weekdagIndex() {
        // 17 augustus 2026 is een maandag.
        #expect(PlanSchedule.weekdayIndex(of: datum(2026, 8, 17), calendar: testCalendar) == 0)
        #expect(PlanSchedule.weekdayIndex(of: datum(2026, 8, 23), calendar: testCalendar) == 6)
    }

    @Test("De volgende dagwissel is middernacht van morgen")
    func volgendeDagwissel() {
        let volgende = PlanSchedule.nextRolloverDate(after: datum(2026, 8, 20, uur: 22), calendar: testCalendar)
        #expect(volgende == testCalendar.startOfDay(for: datum(2026, 8, 21)))
    }
}

/// Wat de widget en de complicatie tonen. Die code draait in een extensie, dus
/// de berekening eronder hoort in de kern te staan waar een test erbij kan.
@Suite("Vooruitkijken voor de widget")
struct DishesForComingDaysTests {

    private func namen(_ dagen: [Dish?]) -> [String?] { dagen.map { $0?.name } }

    @Test("Vandaag en morgen zijn de eerste twee gerechten")
    func vandaagEnMorgen() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep", "Pasta")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 20), calendar: testCalendar, autoAdvance: true)
        #expect(namen(dagen) == ["Pizza", "Soep"])
    }

    @Test("Na twee dagen schuift het paar mee")
    func schuiftMee() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep", "Pasta", "Zalm")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 22), calendar: testCalendar, autoAdvance: true)
        #expect(namen(dagen) == ["Pasta", "Zalm"])
    }

    @Test("Zonder automatisch afvinken zijn het de bovenste twee")
    func handmatigeModus() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep", "Pasta")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 25), calendar: testCalendar, autoAdvance: false)
        #expect(namen(dagen) == ["Pizza", "Soep"])
    }

    @Test("Is vandaag al gegeten, dan is vandaag leeg en morgen gevuld")
    func vandaagAlGegeten() {
        // Anker op morgen: het gerecht van vandaag is al afgestreept.
        let plan = planning(vanaf: datum(2026, 8, 21), "Soep", "Pasta")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 20), calendar: testCalendar, autoAdvance: true)
        #expect(namen(dagen) == [nil, "Soep"])
        #expect(PlanSchedule.dayOffset(in: plan, at: datum(2026, 8, 20), calendar: testCalendar) == -1)
    }

    @Test("Is er nog maar één gerecht, dan blijft morgen leeg")
    func laatsteGerecht() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza", "Soep")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 21), calendar: testCalendar, autoAdvance: true)
        #expect(namen(dagen) == ["Soep", nil])
    }

    @Test("Een opgedroogde lijst levert niets op in plaats van een crash")
    func lijstOp() {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza")
        let dagen = PlanSchedule.dishesForComingDays(2, in: plan, at: datum(2026, 8, 30), calendar: testCalendar, autoAdvance: true)
        #expect(namen(dagen) == [nil, nil])
    }
}
