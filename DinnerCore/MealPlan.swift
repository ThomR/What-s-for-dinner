import Foundation

/// De volledige planning: de wachtrij met gerechten, de dag waarop het bovenste
/// gerecht aan de beurt is, en het logboek van wat er al gegeten is.
///
/// De wachtrij verschuift niet uit zichzelf. Welk gerecht *vandaag* aan de beurt
/// is volgt uit `anchorDate` en de kalender, zodat de Watch en de widgets dat
/// zelf kunnen uitrekenen zonder dat de iPhone-app heeft gedraaid.
struct MealPlan: Codable, Equatable, Sendable {
    /// De geplande gerechten, op volgorde. `dishes[0]` hoort bij `anchorDate`.
    var dishes: [Dish]
    /// Het begin van de dag waarop `dishes[0]` aan de beurt is.
    var anchorDate: Date
    /// Gegeten gerechten, in willekeurige volgorde — sorteer pas bij weergave.
    var log: [ServedMeal]

    init(dishes: [Dish] = [], anchorDate: Date = Date(), log: [ServedMeal] = []) {
        self.dishes = dishes
        self.anchorDate = anchorDate
        self.log = log
    }

    static let empty = MealPlan(dishes: [], anchorDate: .distantPast, log: [])

    var isEmpty: Bool { dishes.isEmpty }
}

/// Alle datumrekenkunde rond een planning. Bewust vrij van globale toestand:
/// `now` en `calendar` komen altijd van buiten, zodat dit te testen is.
enum PlanSchedule {

    /// Aantal hele kalenderdagen tussen twee momenten, nooit negatief.
    ///
    /// Negatieve uitkomsten worden afgekapt op 0: als de klok terugloopt (reis
    /// naar een andere tijdzone, gebruiker zet de datum terug) mag de planning
    /// niet achteruit springen.
    static func elapsedDays(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let days = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(0, days)
    }

    /// De dag waarop het gerecht op positie `offset` in de wachtrij aan de beurt is.
    static func plannedDate(offset: Int, anchorDate: Date, calendar: Calendar = .current) -> Date {
        let anchor = calendar.startOfDay(for: anchorDate)
        return calendar.date(byAdding: .day, value: offset, to: anchor) ?? anchor
    }

    /// Hoeveel gerechten er inmiddels gegeten hadden moeten zijn.
    ///
    /// Nooit meer dan er in de wachtrij staan: een lege lijst loopt niet verder
    /// achter naarmate de app langer ongebruikt blijft.
    static func servedCount(in plan: MealPlan, at now: Date, calendar: Calendar = .current) -> Int {
        min(elapsedDays(from: plan.anchorDate, to: now, calendar: calendar), plan.dishes.count)
    }

    /// Het gerecht van vandaag, zonder de planning te wijzigen. Dit is wat de
    /// widget en de complicatie tonen.
    static func currentDish(in plan: MealPlan, at now: Date, calendar: Calendar = .current, autoAdvance: Bool) -> Dish? {
        dishesForComingDays(1, in: plan, at: now, calendar: calendar, autoAdvance: autoAdvance)[0]
    }

    /// Hoeveel dagen het anker achter ligt op vandaag, met teken.
    ///
    /// Negatief betekent dat het anker in de toekomst ligt: het gerecht van
    /// vandaag is al gegeten en het bovenste gerecht is voor morgen of later.
    static func dayOffset(in plan: MealPlan, at now: Date, calendar: Calendar = .current) -> Int {
        let anchor = calendar.startOfDay(for: plan.anchorDate)
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: anchor, to: today).day ?? 0
    }

    /// Het gerecht per dag, vanaf vandaag: `[0]` is vandaag, `[1]` morgen.
    ///
    /// Een plek is `nil` als er voor die dag niets gepland staat — omdat het
    /// gerecht van vandaag al gegeten is, of omdat de lijst opraakt. Hier bouwen
    /// de widget en de complicatie hun weergave mee op.
    ///
    /// Zonder automatisch afvinken bestaat "vandaag" niet echt en zijn het
    /// gewoon de bovenste gerechten van de lijst.
    static func dishesForComingDays(
        _ count: Int,
        in plan: MealPlan,
        at now: Date,
        calendar: Calendar = .current,
        autoAdvance: Bool
    ) -> [Dish?] {
        guard count > 0 else { return [] }
        let start = autoAdvance ? dayOffset(in: plan, at: now, calendar: calendar) : 0
        return (0..<count).map { day in
            let index = start + day
            return plan.dishes.indices.contains(index) ? plan.dishes[index] : nil
        }
    }

    /// De planning zoals die er vandaag uitziet: alles wat volgens de kalender al
    /// gegeten is verhuist naar het logboek, met de dag waarop het aan de beurt was.
    ///
    /// Idempotent — twee keer uitvoeren op dezelfde dag verandert niets meer.
    static func advanced(_ plan: MealPlan, to now: Date, calendar: Calendar = .current, autoAdvance: Bool) -> MealPlan {
        var updated = plan
        let today = calendar.startOfDay(for: now)

        guard autoAdvance else {
            // Zonder automatisch doorschuiven begint de lijst altijd vandaag; de
            // gebruiker streept zelf af. Zo kloppen de daglabels toch.
            updated.anchorDate = today
            return updated
        }

        // Een anker in de toekomst blijft staan: dan is het gerecht van vandaag
        // al gegeten en is het bovenste gerecht voor morgen. servedCount levert
        // dan 0 op, dus er gebeurt niets tot die dag er is.

        let served = servedCount(in: plan, at: now, calendar: calendar)
        if served > 0 {
            for offset in 0..<served {
                let date = plannedDate(offset: offset, anchorDate: plan.anchorDate, calendar: calendar)
                updated.log.append(ServedMeal(dish: plan.dishes[offset], servedOn: date))
            }
            updated.dishes.removeFirst(served)
        }

        // Is de wachtrij leeg gelopen, dan begint een nieuw gerecht vandaag en
        // niet op de dag waarop de lijst toevallig opraakte — tenzij vandaag al
        // gegeten is, dan is morgen de eerste vrije dag.
        let next = plannedDate(offset: served, anchorDate: plan.anchorDate, calendar: calendar)
        updated.anchorDate = updated.dishes.isEmpty ? max(today, next) : next

        return updated
    }

    /// Een gerecht is gegeten: het gaat naar het logboek.
    ///
    /// Was het het bovenste gerecht, dan houdt de rest zijn dag. In 2.0 schoof
    /// het volgende gerecht hier naar vandaag, en werd het om middernacht óók
    /// met de datum van vandaag afgestreept — twee gerechten op één dag.
    static func serving(
        _ plan: MealPlan,
        dishID: UUID,
        at now: Date,
        calendar: Calendar = .current,
        autoAdvance: Bool
    ) -> MealPlan {
        guard let index = plan.dishes.firstIndex(where: { $0.id == dishID }) else { return plan }
        var updated = plan
        let today = calendar.startOfDay(for: now)
        let planned = plannedDate(offset: index, anchorDate: plan.anchorDate, calendar: calendar)
        // Wie vooruit eet, eet vandaag — niet op de dag waarvoor het gepland stond.
        updated.log.append(ServedMeal(dish: plan.dishes[index], servedOn: min(planned, today)))
        updated.dishes.remove(at: index)

        if index == 0 {
            updated.anchorDate = autoAdvance
                ? plannedDate(offset: 1, anchorDate: plan.anchorDate, calendar: calendar)
                : today
        }
        return updated
    }

    /// Een gerecht is geschrapt zonder gegeten te zijn. Het volgende neemt zijn
    /// dag over, dus het anker blijft staan.
    static func removing(_ plan: MealPlan, dishID: UUID) -> MealPlan {
        var updated = plan
        updated.dishes.removeAll { $0.id == dishID }
        return updated
    }

    /// Het eerstvolgende moment waarop de planning verandert, voor het plannen van
    /// widget-updates. Dat is middernacht van de volgende dag.
    static func nextRolloverDate(after now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
    }
}

/// Hoe een geplande dag benoemd wordt. De vertaling naar tekst gebeurt in de UI,
/// zodat deze laag vrij blijft van SwiftUI en overal getest kan worden.
enum DayLabel: Equatable, Sendable {
    case today
    case tomorrow
    /// 0 = maandag, 6 = zondag. Sluit aan op de bestaande vertaalsleutels.
    case weekday(Int)
    /// Verder dan een week vooruit; een weekdagnaam zou dan dubbelzinnig zijn.
    case date(Date)
}

extension PlanSchedule {
    /// De weekdag van een datum, 0 = maandag.
    static func weekdayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    static func dayLabel(for date: Date, at now: Date, calendar: Calendar = .current) -> DayLabel {
        switch elapsedDays(from: now, to: date, calendar: calendar) {
        case 0: return .today
        case 1: return .tomorrow
        case 2...6: return .weekday(weekdayIndex(of: date, calendar: calendar))
        default: return .date(calendar.startOfDay(for: date))
        }
    }
}
