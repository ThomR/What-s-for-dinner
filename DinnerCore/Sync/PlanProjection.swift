import Foundation

/// Bouwt een planning op uit losse records, zoals ze uit iCloud komen.
///
/// De volgorde staat in één apart record en de gerechten zijn losse records.
/// Dat is met opzet: voegen jij en je partner tegelijk iets toe, dan zijn dat
/// twee verschillende records en raakt er niets kwijt. Alleen over de volgorde
/// kan onenigheid ontstaan, en daar wint de laatste schrijver — bij een lijstje
/// voor twee mensen is dat de voorspelbaarste uitkomst.
enum PlanProjection {

    /// Zet de losse onderdelen om in één planning.
    ///
    /// Gerechten die nog niet in de bekende volgorde staan — net toegevoegd door
    /// de ander — komen achteraan, op tijd van toevoegen. Zo verdwijnt een
    /// gerecht nooit doordat de volgorde nog niet is bijgewerkt.
    static func rebuild(
        dishes: [UUID: Dish],
        order: [UUID],
        anchorDate: Date,
        log: [UUID: ServedMeal]
    ) -> MealPlan {
        var used = Set<UUID>()
        var ordered: [Dish] = []

        for id in order {
            guard let dish = dishes[id], used.insert(id).inserted else { continue }
            ordered.append(dish)
        }

        let leftovers = dishes.values
            .filter { !used.contains($0.id) }
            .sorted { ($0.addedAt, $0.id.uuidString) < ($1.addedAt, $1.id.uuidString) }

        return MealPlan(
            dishes: ordered + leftovers,
            anchorDate: anchorDate,
            log: log.values.sorted { ($0.servedOn, $0.id.uuidString) < ($1.servedOn, $1.id.uuidString) }
        )
    }

    /// De volgorde zoals die opgeslagen moet worden.
    static func order(of plan: MealPlan) -> [UUID] {
        plan.dishes.map(\.id)
    }

    /// Welke records er veranderd of verdwenen zijn tussen twee planningen.
    /// Hiermee weet de synchronisatie wat er verstuurd moet worden zonder elke
    /// keer alles opnieuw op te sturen.
    static func changes(from old: MealPlan, to new: MealPlan) -> PlanChanges {
        let oldDishes = Dictionary(uniqueKeysWithValues: old.dishes.map { ($0.id, $0) })
        let newDishes = Dictionary(uniqueKeysWithValues: new.dishes.map { ($0.id, $0) })
        let oldMeals = Dictionary(uniqueKeysWithValues: old.log.map { ($0.id, $0) })
        let newMeals = Dictionary(uniqueKeysWithValues: new.log.map { ($0.id, $0) })

        return PlanChanges(
            changedDishes: newDishes.values.filter { oldDishes[$0.id] != $0 }.map(\.id).sorted { $0.uuidString < $1.uuidString },
            removedDishes: oldDishes.keys.filter { newDishes[$0] == nil }.sorted { $0.uuidString < $1.uuidString },
            changedMeals: newMeals.values.filter { oldMeals[$0.id] != $0 }.map(\.id).sorted { $0.uuidString < $1.uuidString },
            removedMeals: oldMeals.keys.filter { newMeals[$0] == nil }.sorted { $0.uuidString < $1.uuidString },
            metadataChanged: old.anchorDate != new.anchorDate || order(of: old) != order(of: new)
        )
    }
}

/// Wat er sinds de vorige stand veranderd is.
struct PlanChanges: Equatable {
    var changedDishes: [UUID] = []
    var removedDishes: [UUID] = []
    var changedMeals: [UUID] = []
    var removedMeals: [UUID] = []
    /// Volgorde of ankerdatum gewijzigd.
    var metadataChanged = false

    var isEmpty: Bool {
        changedDishes.isEmpty && removedDishes.isEmpty
            && changedMeals.isEmpty && removedMeals.isEmpty && !metadataChanged
    }
}
