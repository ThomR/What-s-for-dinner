import Testing
import Foundation

/// Onder welke naam elk onderdeel van de planning in iCloud staat.
///
/// Dit is de regel die in 2.0.1 ontbrak. Een gerecht en zijn logregel houden met
/// opzet dezelfde `id` — streept de app op twee toestellen om middernacht
/// hetzelfde gerecht af, dan is dat daardoor één logregel en niet twee. Maar ze
/// deelden ook hun recordnaam, en dan levert afstrepen of terugzetten een
/// bewaar- én een verwijderopdracht voor hetzelfde record op. CloudKit houdt
/// daar maar één van over, en zo verdween een gerecht dat uit de geschiedenis
/// werd teruggezet bij de partner van de lijst.
@Suite("Recordnamen voor iCloud")
struct RecordnamenTests {

    private typealias Naam = CloudSchema.RecordName

    @Test("Een gerecht en zijn logregel hebben dezelfde identiteit maar niet dezelfde recordnaam")
    func zelfdeIdAndereNaam() {
        let lasagne = gerecht("Lasagne")
        let gegeten = ServedMeal(dish: lasagne, servedOn: datum(2026, 9, 20))

        #expect(gegeten.id == lasagne.id, "dezelfde identiteit is met opzet")
        #expect(Naam.dish(lasagne.id) != Naam.meal(gegeten.id))
    }

    @Test("Een recordnaam is terug te lezen als waar hij over gaat")
    func naamTerugLezen() {
        let id = UUID()
        #expect(Naam.kind(of: Naam.dish(id)) == .dish(id))
        #expect(Naam.kind(of: Naam.meal(id)) == .meal(id))
        #expect(Naam.kind(of: CloudSchema.planRecordName) == .plan)
        #expect(Naam.kind(of: "zomaar iets") == nil)
    }

    @Test("Afstrepen bewaart en verwijdert nooit hetzelfde record")
    func afstrepen() {
        var nieuw = planning(vanaf: datum(2026, 9, 20), "Lasagne", "Soep")
        let oud = nieuw
        let lasagne = nieuw.dishes[0]
        nieuw = PlanSchedule.serving(
            nieuw,
            dishID: lasagne.id,
            at: datum(2026, 9, 20, uur: 20),
            calendar: testCalendar,
            autoAdvance: false
        )

        let records = Naam.records(for: PlanProjection.changes(from: oud, to: nieuw))
        #expect(records.delete == [Naam.dish(lasagne.id)])
        #expect(records.save.contains(Naam.meal(lasagne.id)))
        #expect(Set(records.save).isDisjoint(with: records.delete))
    }

    @Test("Terugzetten uit de geschiedenis verwijdert het gerecht niet bij de ander")
    func terugzetten() {
        // Precies de reeks die lasagne bij Karin van de lijst haalde: afstrepen,
        // en het daarna uit de geschiedenis terugzetten.
        var plan = planning(vanaf: datum(2026, 9, 20), "Lasagne")
        let lasagne = plan.dishes[0]
        plan = PlanSchedule.serving(
            plan,
            dishID: lasagne.id,
            at: datum(2026, 9, 20, uur: 20),
            calendar: testCalendar,
            autoAdvance: false
        )

        var terug = plan
        let logregel = terug.log.removeFirst()
        terug.dishes.append(logregel.restored(at: datum(2026, 9, 21)))

        let records = Naam.records(for: PlanProjection.changes(from: plan, to: terug))
        #expect(records.save.contains(Naam.dish(lasagne.id)))
        #expect(records.delete == [Naam.meal(lasagne.id)])
        #expect(Set(records.save).isDisjoint(with: records.delete))
    }

    @Test("Alleen van volgorde wisselen stuurt alleen het plan-record")
    func alleenVolgorde() {
        let oud = planning(vanaf: datum(2026, 9, 20), "Lasagne", "Soep")
        var nieuw = oud
        nieuw.dishes.reverse()

        let records = Naam.records(for: PlanProjection.changes(from: oud, to: nieuw))
        #expect(records.save == [CloudSchema.planRecordName])
        #expect(records.delete.isEmpty)
    }
}
