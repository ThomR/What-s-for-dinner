import Foundation
import SwiftUI
import WidgetKit

/// De planning zoals de app hem gebruikt: één bron van waarheid, die na elke
/// wijziging opslaat en de widgets bijwerkt.
@MainActor
final class PlanStore: ObservableObject {

    @Published private(set) var plan: MealPlan
    /// Het begin van de dag waartegen de weergave rekent. Verandert bij een
    /// dagwissel, zodat de hele lijst in één keer verspringt.
    @Published private(set) var today: Date

    private let store: DishStore
    private let calendar: Calendar
    /// Injecteerbaar zodat tests niet van de echte klok afhangen.
    private let now: () -> Date

    init(store: DishStore = .shared, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.calendar = calendar
        self.now = now
        Preferences.migrateIfNeeded()
        self.plan = store.load()
        self.today = calendar.startOfDay(for: now())
        refresh()
    }

    // MARK: - Afgeleide weergave

    /// De gerechten met de dag waarop ze aan de beurt zijn.
    var scheduled: [ScheduledDish] {
        plan.dishes.enumerated().map { index, dish in
            ScheduledDish(
                dish: dish,
                position: index,
                date: PlanSchedule.plannedDate(offset: index, anchorDate: plan.anchorDate, calendar: calendar)
            )
        }
    }

    var log: [ServedMeal] {
        plan.log.sorted { $0.servedOn > $1.servedOn }
    }

    var isEmpty: Bool { plan.dishes.isEmpty }

    // MARK: - Bijwerken

    /// Zet de planning op vandaag. Aanroepen bij opstarten en zodra de app weer
    /// naar voren komt — de dag kan zijn verstreken terwijl de app weg was.
    func refresh() {
        store.invalidateCache()
        let moment = now()
        let startOfToday = calendar.startOfDay(for: moment)
        if today != startOfToday {
            today = startOfToday
        }
        let stored = store.load()
        let advanced = PlanSchedule.advanced(stored, to: moment, calendar: calendar, autoAdvance: Preferences.autoAdvance)
        if advanced != plan {
            plan = advanced
        }
        if advanced != stored {
            persist()
        }
    }

    // MARK: - Bewerkingen

    func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dish = Dish(name: trimmed, emoji: EmojiSuggester.suggest(for: trimmed), addedAt: now())
        // Een gerecht dat bij een lege lijst komt is vanaf vandaag aan de beurt.
        if plan.dishes.isEmpty {
            plan.anchorDate = calendar.startOfDay(for: now())
        }
        plan.dishes.append(dish)
        persist()
        refineEmoji(for: dish.id, name: trimmed, current: dish.emoji)
    }

    func rename(_ dish: Dish, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = plan.dishes.firstIndex(where: { $0.id == dish.id }) else { return }
        guard plan.dishes[index].name != trimmed else { return }
        plan.dishes[index].name = trimmed
        plan.dishes[index].emoji = EmojiSuggester.suggest(for: trimmed)
        persist()
        refineEmoji(for: dish.id, name: trimmed, current: plan.dishes[index].emoji)
    }

    /// Streept een gerecht af: het verhuist naar het logboek met de dag waarop
    /// het gepland stond.
    func serve(_ dish: Dish) {
        guard let index = plan.dishes.firstIndex(where: { $0.id == dish.id }) else { return }
        let date = PlanSchedule.plannedDate(offset: index, anchorDate: plan.anchorDate, calendar: calendar)
        plan.log.append(ServedMeal(dish: plan.dishes[index], servedOn: min(date, calendar.startOfDay(for: now()))))
        plan.dishes.remove(at: index)
        // Het gerecht van vandaag is weg, dus de rest schuift een dag naar voren.
        if index == 0, !plan.dishes.isEmpty {
            plan.anchorDate = calendar.startOfDay(for: now())
        }
        persist()
    }

    /// Verwijdert zonder het in het logboek te zetten.
    func remove(_ dish: Dish) {
        guard let index = plan.dishes.firstIndex(where: { $0.id == dish.id }) else { return }
        plan.dishes.remove(at: index)
        if index == 0, !plan.dishes.isEmpty {
            plan.anchorDate = calendar.startOfDay(for: now())
        }
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        plan.dishes.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Zet een gegeten gerecht terug achteraan de wachtrij.
    func restore(_ meal: ServedMeal) {
        guard let index = plan.log.firstIndex(where: { $0.id == meal.id }) else { return }
        let removed = plan.log.remove(at: index)
        if plan.dishes.isEmpty {
            plan.anchorDate = calendar.startOfDay(for: now())
        }
        plan.dishes.append(removed.restored(at: now()))
        persist()
    }

    /// Leegt de wachtrij. Het logboek blijft staan — dat is de geschiedenis.
    func clearQueue() {
        plan.dishes.removeAll()
        plan.anchorDate = calendar.startOfDay(for: now())
        persist()
    }

    func clearLog() {
        plan.log.removeAll()
        persist()
    }

    func replaceAll(with dishes: [Dish]) {
        plan.dishes = dishes
        plan.anchorDate = calendar.startOfDay(for: now())
        persist()
    }

    // MARK: - Opslaan

    private func persist() {
        store.save(plan)
        WidgetCenter.shared.reloadAllTimelines()
        PlanSyncBridge.shared.planDidChange(plan)
    }

    /// Vraagt het taalmodel om een betere emoji als de woordenlijst er niet
    /// uitkwam. Gebeurt op de achtergrond: de gebruiker wacht nergens op.
    private func refineEmoji(for id: UUID, name: String, current: String) {
        guard EmojiSuggester.isUncertain(current), EmojiIntelligence.isAvailable else { return }
        Task { [weak self] in
            guard let better = await EmojiIntelligence.suggest(for: name) else { return }
            guard let self, let index = self.plan.dishes.firstIndex(where: { $0.id == id }) else { return }
            guard self.plan.dishes[index].emoji == current else { return }
            self.plan.dishes[index].emoji = better
            self.persist()
        }
    }
}

/// Een gerecht met de dag waarop het aan de beurt is.
struct ScheduledDish: Identifiable, Equatable {
    let dish: Dish
    let position: Int
    let date: Date

    var id: UUID { dish.id }
}
