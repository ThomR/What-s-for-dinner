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

    init(appGroup: String) {
        self.appGroup = appGroup
    }

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    // MARK: - Lezen en schrijven

    func load() -> MealPlan {
        queue.sync {
            if let cached { return cached }
            let plan = readFromDisk() ?? migrateLegacyData() ?? MealPlan(dishes: [], anchorDate: Date(), log: [])
            cached = plan
            return plan
        }
    }

    func save(_ plan: MealPlan) {
        queue.sync {
            cached = plan
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
    }

    /// Gooit de cache weg zodat een volgende `load()` van schijf leest. Nodig in
    /// extensies, die blijven leven tussen twee weergaven door.
    func invalidateCache() {
        queue.sync { cached = nil }
    }

    private func readFromDisk() -> MealPlan? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try JSONDecoder.plan.decode(MealPlan.self, from: data)
        } catch {
            Log.store.error("Planning onleesbaar: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Migratie

    /// Zet de opslag van vóór versie 2 om: twee losse `UserDefaults`-sleutels met
    /// gerechten en afgeronde gerechten, zonder ankerdatum.
    private func migrateLegacyData() -> MealPlan? {
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
        save(plan)
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
