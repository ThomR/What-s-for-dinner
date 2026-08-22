import Foundation

/// Leest en schrijft de planning in de App Group, zodat app, widget en Watch
/// dezelfde gegevens zien.
///
/// De planning staat in één JSON-bestand in de gedeelde container. Een bestand
/// in plaats van `UserDefaults`, omdat het schrijven atomair is en de lijst kan
/// groeien; het logboek van een jaar past niet netjes in een preference.
final class DishStore: @unchecked Sendable {

    /// Welke gedeelde container gebruikt wordt. iPhone en Watch hebben elk hun
    /// eigen App Group, omdat het aparte apparaten met aparte sandboxen zijn.
    enum Group {
        static let phone = "group.whatsfordinner.shared"
        static let watch = "group.whatsfordinner.watchshared"
    }

    static let phoneStore = DishStore(appGroup: Group.phone)
    static let watchStore = DishStore(appGroup: Group.watch)

    /// De store die hoort bij het platform waarop deze code draait.
    static var shared: DishStore {
        #if os(watchOS)
        return watchStore
        #else
        return phoneStore
        #endif
    }

    private let appGroup: String
    private let fileName = "mealplan.json"
    private let queue = DispatchQueue(label: "nl.whatsfordinner.dishstore")
    private var cached: MealPlan?
    /// Overschrijft de App Group-map. Alleen voor tests.
    private let containerOverride: URL?

    init(appGroup: String, containerURL: URL? = nil) {
        self.appGroup = appGroup
        self.containerOverride = containerURL
    }

    private var fileURL: URL? {
        let container = containerOverride ?? FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        return container?.appendingPathComponent(fileName)
    }

    // MARK: - Lezen en schrijven

    func load() -> MealPlan {
        queue.sync { loadLocked() }
    }

    func save(_ plan: MealPlan) {
        queue.sync {
            cached = plan
            writeLocked(plan)
        }
    }

    /// Gooit de cache weg zodat een volgende `load()` van schijf leest. Nodig in
    /// extensies, die blijven leven tussen twee weergaven door.
    func invalidateCache() {
        queue.sync { cached = nil }
    }

    // MARK: - Draait al op de queue
    //
    // Alles hieronder wordt alleen aangeroepen vanuit een `queue.sync`-blok en
    // mag zelf dus niet opnieuw locken: `queue` is serieel, en er nog een keer
    // synchroon op wachten van binnenuit is een deadlock die als crash eindigt.

    private func loadLocked() -> MealPlan {
        if let cached { return cached }
        let plan = readLocked() ?? migrateLegacyLocked() ?? MealPlan(dishes: [], anchorDate: Date(), log: [])
        cached = plan
        return plan
    }

    private func readLocked() -> MealPlan? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try JSONDecoder.plan.decode(MealPlan.self, from: data)
        } catch {
            Log.store.error("Planning onleesbaar: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func writeLocked(_ plan: MealPlan) {
        guard let fileURL else {
            // Zonder werkende App Group draait de app door op de cache; beter
            // een sessie zonder widget dan een app die niets meer opslaat.
            Log.store.error("App Group \(self.appGroup, privacy: .public) niet beschikbaar, planning niet bewaard")
            return
        }
        do {
            let data = try JSONEncoder.plan.encode(plan)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.store.error("Opslaan mislukt: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Migratie

    /// Zet de opslag van vóór versie 2 om: twee losse `UserDefaults`-sleutels met
    /// gerechten en afgeronde gerechten, zonder ankerdatum.
    private func migrateLegacyLocked() -> MealPlan? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        let legacyDishes = defaults.data(forKey: "dishes").flatMap { try? JSONDecoder().decode([LegacyDish].self, from: $0) }
        let legacyWatch = defaults.data(forKey: "watchDishes").flatMap { try? JSONDecoder().decode([LegacyDish].self, from: $0) }
        let legacyCompleted = defaults.data(forKey: "completedDishes").flatMap { try? JSONDecoder().decode([LegacyDish].self, from: $0) }

        guard let dishes = legacyDishes ?? legacyWatch else { return nil }

        let now = Date()
        let plan = MealPlan(
            dishes: dishes.map { $0.migrated(addedAt: now) },
            anchorDate: now,
            log: (legacyCompleted ?? []).map { $0.migratedServed() }
        )
        Log.store.info("Oude planning omgezet: \(plan.dishes.count) gerechten, \(plan.log.count) in logboek")
        writeLocked(plan)
        return plan
    }

    /// Het gerecht zoals versie 1 het bewaarde.
    private struct LegacyDish: Codable {
        let id: UUID
        let name: String
        let emoji: String
        let completedDate: Date?

        func migrated(addedAt: Date) -> Dish {
            Dish(id: id, name: name, emoji: emoji, addedAt: addedAt)
        }

        func migratedServed() -> ServedMeal {
            ServedMeal(id: id, name: name, emoji: emoji, servedOn: completedDate ?? Date.distantPast)
        }
    }
}

extension JSONEncoder {
    /// Datums als ISO-8601, zodat het bestand leesbaar blijft en later ook door
    /// een andere versie van de app te lezen is.
    static let plan: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let plan: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
