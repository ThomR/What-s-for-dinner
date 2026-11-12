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
    /// De lijst is van een ander en je mag hem alleen bekijken.
    @Published private(set) var isReadOnly: Bool
    /// De lijst is van een ander (en je mag hem misschien wel wijzigen).
    @Published private(set) var isSharedList: Bool

    private let store: DishStore
    /// De vorige stand, om te bepalen wat er naar iCloud moet.
    private var lastPersisted: MealPlan
    private let calendar: Calendar
    /// Injecteerbaar zodat tests niet van de echte klok afhangen.
    private let now: () -> Date
    /// Injecteerbaar zodat tests niet van de gedeelde instellingen afhangen.
    private let autoAdvance: () -> Bool
    /// Idem: of de lijst van een ander is, en of je hem alleen mag bekijken.
    private let sharing: () -> (shared: Bool, readOnly: Bool)

    init(
        store: DishStore = .shared,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        autoAdvance: @escaping () -> Bool = { Preferences.autoAdvance },
        sharing: @escaping () -> (shared: Bool, readOnly: Bool) = {
            (Preferences.usesSharedList, Preferences.isReadOnlyList)
        }
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.autoAdvance = autoAdvance
        self.sharing = sharing
        let state = sharing()
        self.isSharedList = state.shared
        self.isReadOnly = state.readOnly
        Preferences.migrateIfNeeded()
        let loaded = store.load()
        self.plan = loaded
        self.lastPersisted = loaded
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
        syncSharingState()
        store.invalidateCache()
        let moment = now()
        let startOfToday = calendar.startOfDay(for: moment)
        if today != startOfToday {
            today = startOfToday
        }
        let stored = store.load()
        // Eerst opschonen: een planning met een dubbele id is wat de app in
        // 2.0.2 bij elke start liet crashen. Het verschil gaat gewoon mee naar
        // iCloud, zodat een teruggekeerd gerecht daar ook verdwijnt.
        let advanced = PlanSchedule.advanced(stored.normalized(), to: moment, calendar: calendar, autoAdvance: autoAdvance())
        if advanced != plan {
            plan = advanced
        }
        // Altijd, ook als er niets doorschuift: wat op schijf staat is wat er
        // verstuurd is of uit iCloud kwam, en de volgende bewerking moet
        // daartegen vergeleken worden.
        lastPersisted = stored
        if advanced != stored {
            persist()
        }
    }

    /// Of je in een gedeelde lijst zit en wat je daar mag, kan veranderen door
    /// iets dat de eigenaar doet; dat komt binnen via iCloud.
    private func syncSharingState() {
        let state = sharing()
        if isReadOnly != state.readOnly { isReadOnly = state.readOnly }
        if isSharedList != state.shared { isSharedList = state.shared }
    }

    // MARK: - Bewerkingen
    //
    // Elke bewerking weigert stil als je alleen mag kijken. De knoppen zijn dan
    // al verborgen; dit is de vangrail voor als er toch iets doorheen glipt.

    func add(name: String) {
        guard !isReadOnly else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dish = Dish(name: trimmed, emoji: EmojiSuggester.suggest(for: trimmed), addedAt: now())
        // Een gerecht dat bij een lege lijst komt is vanaf vandaag aan de beurt,
        // of vanaf morgen als het gerecht van vandaag al gegeten is.
        if plan.dishes.isEmpty {
            plan.anchorDate = max(plan.anchorDate, calendar.startOfDay(for: now()))
        }
        plan.dishes.append(dish)
        persist()
        refineEmoji(for: dish.id, name: trimmed, current: dish.emoji)
    }

    func rename(_ dish: Dish, to name: String) {
        guard !isReadOnly else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = plan.dishes.firstIndex(where: { $0.id == dish.id }) else { return }
        guard plan.dishes[index].name != trimmed else { return }
        plan.dishes[index].name = trimmed
        plan.dishes[index].emoji = EmojiSuggester.suggest(for: trimmed)
        persist()
        refineEmoji(for: dish.id, name: trimmed, current: plan.dishes[index].emoji)
    }

    /// Streept een gerecht af: het verhuist naar het logboek.
    func serve(_ dish: Dish) {
        guard !isReadOnly else { return }
        plan = PlanSchedule.serving(plan, dishID: dish.id, at: now(), calendar: calendar, autoAdvance: autoAdvance())
        persist()
    }

    /// Verwijdert zonder het in het logboek te zetten.
    func remove(_ dish: Dish) {
        guard !isReadOnly else { return }
        plan = PlanSchedule.removing(plan, dishID: dish.id)
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !isReadOnly else { return }
        plan.dishes.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Zet een gegeten gerecht terug achteraan de wachtrij.
    func restore(_ meal: ServedMeal) {
        guard !isReadOnly else { return }
        guard let index = plan.log.firstIndex(where: { $0.id == meal.id }) else { return }
        let removed = plan.log.remove(at: index)
        // Stond het gerecht door een oude iCloud-fout óók nog in de wachtrij,
        // dan niet nog een keer: twee keer dezelfde id laat de app crashen.
        plan.dishes.removeAll { $0.id == removed.id }
        if plan.dishes.isEmpty {
            plan.anchorDate = max(plan.anchorDate, calendar.startOfDay(for: now()))
        }
        plan.dishes.append(removed.restored(at: now()))
        persist()
    }

    /// Leegt de wachtrij. Het logboek blijft staan — dat is de geschiedenis.
    func clearQueue() {
        guard !isReadOnly else { return }
        plan.dishes.removeAll()
        plan.anchorDate = calendar.startOfDay(for: now())
        persist()
    }

    func clearLog() {
        guard !isReadOnly else { return }
        plan.log.removeAll()
        persist()
    }

    func replaceAll(with dishes: [Dish]) {
        guard !isReadOnly else { return }
        plan.dishes = dishes
        plan.anchorDate = calendar.startOfDay(for: now())
        persist()
    }

    // MARK: - Opslaan

    private func persist() {
        let previous = lastPersisted
        lastPersisted = plan
        store.save(plan)
        // De widget bijwerken gaat via XPC naar een andere daemon. Bij het
        // opstarten loopt dit mee vóór het eerste beeldje, en niemand wacht op
        // het antwoord — dus niet op de hoofdactor blijven staan.
        Task { WidgetCenter.shared.reloadAllTimelines() }
        PlanSyncBridge.shared.planDidChange(plan)
        #if canImport(CloudKit) && os(iOS)
        CloudSync.shared.localPlanDidChange(from: previous, to: plan)
        #endif
    }

    /// Neemt over wat er uit iCloud binnenkwam.
    ///
    /// Gewoon `refresh()`: wat binnenkomt kan van gisteren zijn en moet dan
    /// eerst doorschuiven naar vandaag. In 2.0.2 werd het hier zonder meer
    /// getoond, en bleef de app op woensdag staan tot je hem herstartte.
    /// Alleen dat doorschuiven gaat terug naar iCloud; wat er binnenkwam niet,
    /// want dat staat al op schijf en `refresh()` vergelijkt daarmee.
    ///
    /// Widgets en Watch heeft `CloudSync` dan al bijgewerkt — die draait ook
    /// als er geen scherm is. Dit is voor wat je ziet.
    func adoptRemoteChanges() {
        refresh()
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
