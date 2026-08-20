import Foundation

#if canImport(CloudKit) && os(iOS)
import CloudKit

/// Houdt de planning gelijk tussen jouw toestellen én met degene met wie je hem
/// deelt.
///
/// Bewust een laag *bovenop* de lokale opslag en niet ervoor in de plaats: als
/// iCloud uit staat, de gebruiker niet is ingelogd of er geen netwerk is, werkt
/// de app precies zoals daarvoor. Er gaat nooit een scherm op slot omdat de
/// synchronisatie hapert.
///
/// Twee engines, want CloudKit scheidt wat van jou is van wat met je gedeeld is:
/// - de privédatabase bevat je eigen lijst;
/// - de gedeelde database bevat de lijst van je partner, als die jou uitnodigde.
/// Is er een gedeelde lijst, dan is dat de lijst die de app toont — anders zou
/// je met z'n tweeën twee verschillende lijstjes bijhouden.
@available(iOS 17.0, *)
@MainActor
final class CloudSync {

    static let shared = CloudSync()

    /// Welke database de lijst van dit moment bevat.
    enum Scope: String, Sendable {
        case privateDatabase
        case sharedDatabase
    }

    private let container = CKContainer(identifier: CloudSchema.containerIdentifier)
    private let store: DishStore
    private var engines: [Scope: CKSyncEngine] = [:]
    private var stateStores: [Scope: SyncStateStore] = [:]
    private var delegates: [Scope: EngineDelegate] = [:]

    /// De zone waarin onze eigen lijst staat.
    private var privateZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CloudSchema.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// De zone van de gedeelde lijst, zodra we weten dat die er is.
    private(set) var sharedZoneID: CKRecordZone.ID?

    /// Waar de app op dit moment mee werkt.
    private(set) var activeScope: Scope = .privateDatabase

    /// Wordt aangeroepen als iCloud een wijziging aanlevert, zodat de UI kan
    /// bijwerken.
    var onRemoteChange: (@MainActor () -> Void)?

    /// Of er iets is misgegaan dat de gebruiker mag weten.
    @Published private(set) var lastError: String?

    private init(store: DishStore = .phoneStore) {
        self.store = store
    }

    // MARK: - Starten

    private var isStarted = false

    /// Zet de synchronisatie aan. Veilig om vaker aan te roepen.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        Task { await configureEngines() }
    }

    private func configureEngines() async {
        guard await isSignedIn() else {
            Log.sync.info("Geen iCloud-account, synchronisatie blijft uit")
            return
        }
        makeEngine(for: .privateDatabase)
        makeEngine(for: .sharedDatabase)
        await fetchChanges()
    }

    private func isSignedIn() async -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            Log.sync.error("Accountstatus onbekend: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func makeEngine(for scope: Scope) {
        let stateStore = SyncStateStore(scope: scope.rawValue)
        let delegate = EngineDelegate(scope: scope, owner: self, stateStore: stateStore)
        let database = scope == .privateDatabase ? container.privateCloudDatabase : container.sharedCloudDatabase

        var configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: stateStore.loadState().flatMap(Self.decodeState),
            delegate: delegate
        )
        configuration.automaticallySync = true

        stateStores[scope] = stateStore
        delegates[scope] = delegate
        engines[scope] = CKSyncEngine(configuration)

        // De eigen zone moet bestaan voordat er records in kunnen; voor de
        // gedeelde database maakt de eigenaar de zone aan.
        if scope == .privateDatabase {
            engines[scope]?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: privateZoneID))])
        }
    }

    private static func decodeState(_ data: Data) -> CKSyncEngine.State.Serialization? {
        try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    nonisolated fileprivate static func encodeState(_ state: CKSyncEngine.State.Serialization) -> Data? {
        try? JSONEncoder().encode(state)
    }

    // MARK: - Ophalen en versturen

    /// Haalt wijzigingen op. Aanroepen bij het openen van de app en bij een
    /// stille pushmelding.
    func fetchChanges() async {
        for engine in engines.values {
            do {
                try await engine.fetchChanges()
            } catch {
                Log.sync.error("Ophalen mislukt: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Meld een lokale wijziging aan. Wat er precies veranderd is bepaalt welke
    /// records er verstuurd worden.
    func localPlanDidChange(from old: MealPlan, to new: MealPlan) {
        guard let engine = engines[activeScope], let zoneID = activeZoneID else { return }
        let changes = PlanProjection.changes(from: old, to: new)
        guard !changes.isEmpty else { return }

        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for id in changes.changedDishes {
            pending.append(.saveRecord(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)))
        }
        for id in changes.removedDishes {
            pending.append(.deleteRecord(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)))
        }
        for id in changes.changedMeals {
            pending.append(.saveRecord(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)))
        }
        for id in changes.removedMeals {
            pending.append(.deleteRecord(CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)))
        }
        if changes.metadataChanged || !changes.changedDishes.isEmpty || !changes.removedDishes.isEmpty {
            // De volgorde staat in het plan-record, dus dat moet ook mee zodra
            // er een gerecht bij komt of verdwijnt.
            pending.append(.saveRecord(CKRecord.ID(recordName: CloudSchema.planRecordName, zoneID: zoneID)))
        }

        engine.state.add(pendingRecordZoneChanges: pending)
    }

    private var activeZoneID: CKRecordZone.ID? {
        activeScope == .privateDatabase ? privateZoneID : sharedZoneID
    }

    // MARK: - Records maken

    /// Levert het record voor een id, opgebouwd uit de huidige planning.
    fileprivate func record(for recordID: CKRecord.ID, stateStore: SyncStateStore) -> CKRecord? {
        let plan = store.load()

        func base(type: String) -> CKRecord {
            // Systeemvelden hergebruiken, anders ziet CloudKit elke wijziging
            // als een nieuw record en botst het met wat er al staat.
            if let data = stateStore.systemFields(for: recordID.recordName),
               let archiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
                archiver.requiresSecureCoding = true
                if let record = CKRecord(coder: archiver) {
                    archiver.finishDecoding()
                    return record
                }
            }
            return CKRecord(recordType: type, recordID: recordID)
        }

        if recordID.recordName == CloudSchema.planRecordName {
            let record = base(type: CloudSchema.RecordType.plan)
            record[CloudSchema.Field.anchorDate] = plan.anchorDate as CKRecordValue
            record[CloudSchema.Field.order] = PlanProjection.order(of: plan).map(\.uuidString) as CKRecordValue
            return record
        }

        guard let id = UUID(uuidString: recordID.recordName) else { return nil }

        if let dish = plan.dishes.first(where: { $0.id == id }) {
            let record = base(type: CloudSchema.RecordType.dish)
            dish.write(to: record)
            return record
        }
        if let meal = plan.log.first(where: { $0.id == id }) {
            let record = base(type: CloudSchema.RecordType.meal)
            meal.write(to: record)
            return record
        }
        // Het gerecht is lokaal alweer weg; niets te versturen.
        return nil
    }

    // MARK: - Binnengekomen wijzigingen verwerken

    fileprivate func apply(
        modifications: [CKRecord],
        deletions: [CKRecord.ID],
        scope: Scope,
        stateStore: SyncStateStore
    ) {
        guard !modifications.isEmpty || !deletions.isEmpty else { return }

        // Een wijziging in de gedeelde database betekent dat er een lijst met
        // ons gedeeld is; die heeft voorrang op onze eigen.
        if scope == .sharedDatabase, let zoneID = modifications.first?.recordID.zoneID {
            sharedZoneID = zoneID
            activeScope = .sharedDatabase
        }
        guard scope == activeScope else { return }

        let plan = store.load()
        var dishes = Dictionary(uniqueKeysWithValues: plan.dishes.map { ($0.id, $0) })
        var meals = Dictionary(uniqueKeysWithValues: plan.log.map { ($0.id, $0) })
        var order = PlanProjection.order(of: plan)
        var anchor = plan.anchorDate

        for record in modifications {
            // Systeemvelden bewaren voor de volgende keer dat we dit record sturen.
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: archiver)
            stateStore.setSystemFields(archiver.encodedData, for: record.recordID.recordName)

            switch record.recordType {
            case CloudSchema.RecordType.dish:
                if let dish = Dish(record: record) { dishes[dish.id] = dish }
            case CloudSchema.RecordType.meal:
                if let meal = ServedMeal(record: record) { meals[meal.id] = meal }
            case CloudSchema.RecordType.plan:
                if let stored = record[CloudSchema.Field.order] as? [String] {
                    order = stored.compactMap(UUID.init(uuidString:))
                }
                if let stored = record[CloudSchema.Field.anchorDate] as? Date {
                    anchor = stored
                }
            default:
                break
            }
        }

        for recordID in deletions {
            stateStore.setSystemFields(nil, for: recordID.recordName)
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            dishes[id] = nil
            meals[id] = nil
        }

        let merged = PlanProjection.rebuild(dishes: dishes, order: order, anchorDate: anchor, log: meals)
        guard merged != plan else { return }
        store.save(merged)
        onRemoteChange?()
        Log.sync.info("Wijziging uit iCloud verwerkt: \(merged.dishes.count) gerechten")
    }

    fileprivate func handleAccountChange(_ changeType: CKSyncEngine.Event.AccountChange.ChangeType) {
        switch changeType {
        case .signIn:
            Task { await fetchChanges() }
        case .signOut, .switchAccounts:
            // De records van de vorige gebruiker zeggen niets over de nieuwe.
            for store in stateStores.values { store.reset() }
            sharedZoneID = nil
            activeScope = .privateDatabase
        @unknown default:
            break
        }
    }

    fileprivate func report(_ error: Error) {
        Log.sync.error("Synchronisatiefout: \(error.localizedDescription, privacy: .public)")
        lastError = error.localizedDescription
    }
}

// MARK: - Delegate

/// Aparte delegate per database, zodat beide engines hun eigen toestand houden.
@available(iOS 17.0, *)
private final class EngineDelegate: NSObject, CKSyncEngineDelegate {
    private let scope: CloudSync.Scope
    private let owner: CloudSync
    private let stateStore: SyncStateStore

    init(scope: CloudSync.Scope, owner: CloudSync, stateStore: SyncStateStore) {
        self.scope = scope
        self.owner = owner
        self.stateStore = stateStore
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            stateStore.saveState(CloudSync.encodeState(update.stateSerialization))

        case .accountChange(let change):
            await owner.handleAccountChange(change.changeType)

        case .fetchedRecordZoneChanges(let changes):
            let records = changes.modifications.map(\.record)
            let deleted = changes.deletions.map(\.recordID)
            await owner.apply(modifications: records, deletions: deleted, scope: scope, stateStore: stateStore)

        case .sentRecordZoneChanges(let sent):
            for saved in sent.savedRecords {
                let archiver = NSKeyedArchiver(requiringSecureCoding: true)
                saved.encodeSystemFields(with: archiver)
                stateStore.setSystemFields(archiver.encodedData, for: saved.recordID.recordName)
            }
            for failure in sent.failedRecordSaves {
                await owner.report(failure.error)
            }

        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await owner.record(for: recordID, stateStore: stateStore)
        }
    }
}
#endif
