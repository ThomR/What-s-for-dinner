import Foundation

#if canImport(CloudKit) && os(iOS)
import CloudKit
import WidgetKit

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

    /// Pas aanmaken als er echt gesynchroniseerd gaat worden.
    ///
    /// `CKContainer(identifier:)` stopt het programma als het proces de
    /// iCloud-entitlement niet heeft — het gooit geen fout, het crasht. Alleen
    /// al het aanraken van deze klasse mag dat dus niet uitlokken.
    private lazy var container = CKContainer(identifier: CloudSchema.containerIdentifier)
    private let store: DishStore
    private var engines: [Scope: CKSyncEngine] = [:]
    private var stateStores: [Scope: SyncStateStore] = [:]
    private var delegates: [Scope: EngineDelegate] = [:]

    /// De zone waarin onze eigen lijst staat.
    private var privateZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CloudSchema.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// De zone van de gedeelde lijst. Blijft bewaard tussen twee starts.
    private(set) var sharedZoneID: CKRecordZone.ID? = Preferences.sharedZone.map {
        CKRecordZone.ID(zoneName: $0.name, ownerName: $0.owner)
    }

    /// Waar de app op dit moment mee werkt. Blijft bewaard tussen twee starts.
    private(set) var activeScope: Scope = Preferences.usesSharedList ? .sharedDatabase : .privateDatabase

    /// Wordt aangeroepen als iCloud een wijziging aanlevert, zodat het scherm
    /// kan bijwerken. Widgets en Watch hangen hier niet van af; zie `adopt(_:)`.
    var onRemoteChange: (@MainActor () -> Void)?

    private init(store: DishStore = .phoneStore) {
        self.store = store
    }

    // MARK: - Starten

    /// Het opzetten van de engines. Bewaard, zodat een ophaalronde erop kan
    /// wachten in plaats van in een lege lijst engines te kijken.
    private var startTask: Task<Void, Never>?

    /// Zet de synchronisatie aan. Veilig om vaker aan te roepen.
    ///
    /// Hoort bij het opstarten van de app, niet bij het eerste scherm. Een
    /// stille push van je partner start de app op de achtergrond zonder
    /// venster; de engine moet er dan al zijn om de wijziging op te halen.
    func start() {
        guard CloudAvailability.isEnabled else {
            Log.sync.info("Gebouwd zonder CloudKit, synchronisatie blijft uit")
            return
        }
        guard startTask == nil else { return }
        startTask = Task { await configureEngines() }
    }

    private func configureEngines() async {
        guard await isSignedIn() else {
            Log.sync.info("Geen iCloud-account, synchronisatie blijft uit")
            return
        }
        makeEngine(for: .privateDatabase)
        makeEngine(for: .sharedDatabase)
        repairRecordNames()
        sendChangesMadeBeforeStart()
        reconcileRecords()
        await refreshSharedListDetails()
        // Bewust géén fetchChanges() hier. Met `automaticallySync` plant de
        // engine zijn eigen rondes, en zelf vragen op een moment dat er nog geen
        // zones bekend zijn levert alleen een lege ronde op — dat is de
        // "Attempted to acquire an empty collection of resources" in de log.
    }

    /// Brengt iCloud in lijn met de lijst op dit toestel: zet erin wat iCloud
    /// nog nooit heeft gezien, en haalt eruit wat hier niet meer bestaat.
    ///
    /// Het eerste, omdat de container anders leeg blijft tot je toevallig een
    /// gerecht wijzigt: records worden alleen ingepland bij een wijziging, en
    /// een lijst die al bestond vóór 2.0 is nooit gewijzigd. Dan is er ook
    /// niets om te delen en toont het CloudKit-dashboard een lege container.
    ///
    /// Het tweede, omdat 2.0.2 bij een koude start het afvinken van die nacht
    /// nooit verstuurde (zie `sendChangesMadeBeforeStart`). Het logrecord kwam
    /// er via hier wel, maar het gerecht bleef ook staan, en na herinstalleren
    /// stonden al die gegeten gerechten weer in de wachtrij.
    ///
    /// Of een record in iCloud staat, blijkt uit de bewaarde systeemvelden. Dat
    /// is betrouwbaarder dan een eigen "al geüpload"-vlag, want die kan liegen
    /// als het versturen mislukte.
    private func reconcileRecords() {
        // Alleen voor je eigen lijst. Ben je deelnemer, dan is de lijst van de
        // ander en horen zijn records niet in jouw zone.
        guard activeScope == .privateDatabase else { return }
        guard let engine = engines[.privateDatabase], let stateStore = stateStores[.privateDatabase] else { return }

        let plan = store.load()
        let names = plan.dishes.map { CloudSchema.RecordName.dish($0.id) }
            + plan.log.map { CloudSchema.RecordName.meal($0.id) }
        let known = Set(stateStore.knownRecordNames())

        let unsent = names.filter { !known.contains($0) }
        // Alleen gerechten en logregels; het plan-record blijft altijd. Een
        // logregel van vóór 2.0.2 staat onder de blote uuid van zijn gerecht
        // en verdwijnt hier dus ook, net als in `repairRecordNames`.
        let current = Set(names)
        let stale = known.filter { name in
            switch CloudSchema.RecordName.kind(of: name) {
            case .dish, .meal: return !current.contains(name)
            case .plan, nil: return false
            }
        }

        guard !unsent.isEmpty || !stale.isEmpty else { return }
        var pending = unsent.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(privateRecordID($0)) }
            + stale.sorted().map { CKSyncEngine.PendingRecordZoneChange.deleteRecord(privateRecordID($0)) }
        pending.append(.saveRecord(privateRecordID(CloudSchema.planRecordName)))
        engine.state.add(pendingRecordZoneChanges: pending)
        Log.sync.info("\(unsent.count) records voor het eerst naar iCloud, \(stale.count) opgeruimd")
    }

    /// Zet eenmalig de hele eigen lijst opnieuw op de server.
    ///
    /// Nodig na 2.0.1. Daar deelde een logregel zijn recordnaam met het gerecht
    /// waar hij uit kwam (zie `CloudSchema.RecordName`), met twee gevolgen die
    /// zichzelf niet herstellen: een gerecht dat je uit de geschiedenis
    /// terugzette werd op de server verwijderd en verdween bij je partner, en
    /// een gegeten gerecht bleef als `Dish`-record staan en kwam bij de ander
    /// weer in de wachtrij. Opnieuw opsturen zet het eerste recht; het
    /// verwijderen van de oude logrecords het tweede.
    private func repairRecordNames() {
        guard activeScope == .privateDatabase, !Preferences.didRepairRecordNames else { return }
        guard let engine = engines[.privateDatabase] else { return }

        let plan = store.load()
        let queued = Set(plan.dishes.map(\.id))
        var pending = plan.dishes.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(privateRecordID(CloudSchema.RecordName.dish($0.id)))
        }
        for meal in plan.log {
            pending.append(.saveRecord(privateRecordID(CloudSchema.RecordName.meal(meal.id))))
            // Alleen als het gerecht niet óók in de wachtrij staat: dan is dat
            // record een echt gerecht en moet het blijven.
            if !queued.contains(meal.id) {
                pending.append(.deleteRecord(privateRecordID(CloudSchema.RecordName.dish(meal.id))))
            }
        }
        pending.append(.saveRecord(privateRecordID(CloudSchema.planRecordName)))

        engine.state.add(pendingRecordZoneChanges: pending)
        Preferences.didRepairRecordNames = true
        Log.sync.info("Eenmalige reparatie: \(pending.count) records opnieuw naar iCloud")
    }

    private func privateRecordID(_ recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: privateZoneID)
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

    /// Start een ophaalronde los van de huidige taak.
    ///
    /// Nadrukkelijk `Task.detached` en geen gewone `Task`. Een gewone taak erft
    /// de task-locals van zijn aanroeper, en CloudKit markeert daarmee dat je
    /// binnen een delegate-callback zit. Duik je van daaruit opnieuw de engine
    /// in, dan kan CKSyncEngine niet meer garanderen dat het de callbacks op
    /// volgorde aanroept en stopt het het programma met "BUG IN CLIENT OF
    /// CLOUDKIT". Vanuit een delegate mag dit dus nooit anders.
    func scheduleFetch() {
        guard CloudAvailability.isEnabled else { return }
        Task.detached { [self] in await fetchChanges() }
    }

    /// Haalt wijzigingen op. Aanroepen bij het openen van de app en bij een
    /// stille pushmelding — nooit rechtstreeks vanuit een delegate-callback.
    func fetchChanges() async {
        guard CloudAvailability.isEnabled else { return }
        // Bij een koude start door een push loopt het opzetten nog; zonder te
        // wachten valt er niets op te halen en blijft de widget achter.
        start()
        await startTask?.value
        for engine in engines.values {
            do {
                try await engine.fetchChanges()
            } catch {
                Log.sync.error("Ophalen mislukt: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// De stand van vóór de eerste wijziging die kwam voordat de engines er
    /// waren. Zie `sendChangesMadeBeforeStart`.
    private var unsentSince: MealPlan?

    /// Meld een lokale wijziging aan. Wat er precies veranderd is bepaalt welke
    /// records er verstuurd worden.
    func localPlanDidChange(from old: MealPlan, to new: MealPlan) {
        guard canSend else { return }
        guard let engine = engines[activeScope], let zoneID = activeZoneID else {
            // De engines komen pas na het opvragen van de accountstatus, en bij
            // een koude start op een nieuwe dag schuift de planning al eerder
            // door. In 2.0.2 ging dat afvinken hier verloren.
            if CloudAvailability.isEnabled, unsentSince == nil {
                unsentSince = old
            }
            return
        }
        let changes = PlanProjection.changes(from: old, to: new)
        guard !changes.isEmpty else { return }

        func recordID(_ name: String) -> CKRecord.ID {
            CKRecord.ID(recordName: name, zoneID: zoneID)
        }

        // Een gerecht en zijn logregel hebben dezelfde id maar een eigen
        // recordnaam. Afstrepen verstuurt dus een verwijdering én een nieuw
        // record, en niet twee opdrachten voor hetzelfde record — waarvan
        // CloudKit er één zou laten vallen.
        let records = CloudSchema.RecordName.records(for: changes)
        let pending = records.save.map { CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID($0)) }
            + records.delete.map { CKSyncEngine.PendingRecordZoneChange.deleteRecord(recordID($0)) }

        engine.state.add(pendingRecordZoneChanges: pending)
    }

    /// Verstuurt alsnog wat er veranderde voordat de engines er waren, als één
    /// wijziging van de stand van toen naar die van nu.
    private func sendChangesMadeBeforeStart() {
        guard let baseline = unsentSince else { return }
        unsentSince = nil
        localPlanDidChange(from: baseline, to: store.load())
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
            // als een nieuw record en botst het met wat er al staat. Maar nooit
            // over een ander recordtype heen: het type van een record staat
            // vast, en 2.0.1 schreef daardoor logregels in `Dish`-records.
            if let data = stateStore.systemFields(for: recordID.recordName),
               let archiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
                archiver.requiresSecureCoding = true
                if let record = CKRecord(coder: archiver) {
                    archiver.finishDecoding()
                    if record.recordType == type { return record }
                }
            }
            return CKRecord(recordType: type, recordID: recordID)
        }

        switch CloudSchema.RecordName.kind(of: recordID.recordName) {
        case .plan:
            let record = base(type: CloudSchema.RecordType.plan)
            record[CloudSchema.Field.anchorDate] = plan.anchorDate as CKRecordValue
            record[CloudSchema.Field.order] = PlanProjection.order(of: plan).map(\.uuidString) as CKRecordValue
            return record

        case .dish(let id):
            guard let dish = plan.dishes.first(where: { $0.id == id }) else { return nil }
            let record = base(type: CloudSchema.RecordType.dish)
            dish.write(to: record)
            return record

        case .meal(let id):
            guard let meal = plan.log.first(where: { $0.id == id }) else { return nil }
            let record = base(type: CloudSchema.RecordType.meal)
            meal.write(to: record)
            return record

        case nil:
            // Onbekende naam; die hebben wij niet geschreven.
            return nil
        }
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
            let isNieuw = activeScope != .sharedDatabase
            sharedZoneID = zoneID
            activeScope = .sharedDatabase
            Preferences.usesSharedList = true
            Preferences.sharedZone = (zoneID.zoneName, zoneID.ownerName)
            if isNieuw {
                // Je eigen lijst blijft veilig in je eigen zone staan, maar hij
                // mag niet mee de lijst van de ander in. Zonder dit zou je bij
                // het accepteren van een uitnodiging je eigen gerechten bij die
                // van je partner dumpen.
                store.save(MealPlan(dishes: [], anchorDate: Date(), log: []))
            }
        }
        guard scope == activeScope else { return }

        let plan = store.load()
        var dishes = PlanProjection.byID(plan.dishes)
        var meals = PlanProjection.byID(plan.log)
        var order = PlanProjection.order(of: plan)
        var anchor = plan.anchorDate

        // Systeemvelden bewaren voor de volgende keer dat we een record sturen,
        // en weggooien voor wat er niet meer is — in één keer geschreven.
        stateStore.setSystemFields(
            modifications.map { ($0.recordID.recordName, Self.systemFields(of: $0)) }
                + deletions.map { ($0.recordName, nil) }
        )

        for record in modifications {
            switch CloudSchema.RecordName.kind(of: record.recordID.recordName) {
            case .plan:
                if let stored = record[CloudSchema.Field.order] as? [String] {
                    order = stored.compactMap(UUID.init(uuidString:))
                }
                if let stored = record[CloudSchema.Field.anchorDate] as? Date {
                    anchor = stored
                }
            case .dish(let id):
                // Een logregel van vóór 2.0.2 staat onder de naam van het
                // gerecht; alleen het recordtype verraadt dat het er een is.
                if let meal = ServedMeal(record: record, id: id) {
                    meals[id] = meal
                } else if let dish = Dish(record: record) {
                    dishes[id] = dish
                }
            case .meal(let id):
                if let meal = ServedMeal(record: record, id: id) { meals[id] = meal }
            case nil:
                break
            }
        }

        // Per naam, niet per id: een gerecht en zijn logregel hebben dezelfde
        // id, dus het verwijderen van het gerecht mag de logregel niet meenemen.
        for recordID in deletions {
            switch CloudSchema.RecordName.kind(of: recordID.recordName) {
            case .dish(let id): dishes[id] = nil
            case .meal(let id): meals[id] = nil
            case .plan, nil: break
            }
        }

        let merged = PlanProjection.rebuild(dishes: dishes, order: order, anchorDate: anchor, log: meals)
        guard merged != plan else { return }
        adopt(merged)
        Log.sync.info("Wijziging uit iCloud verwerkt: \(merged.dishes.count) gerechten")
    }

    /// Een planning die niet van dit toestel komt: bewaren en overal tonen.
    ///
    /// Widgets en Watch worden hier bijgewerkt en niet via het scherm. Na een
    /// stille push draait de app zonder venster, en dan zou niemand het
    /// doorgeven — de wijziging van je partner verscheen pas op je Watch en
    /// beginscherm als je de app zelf opende.
    private func adopt(_ plan: MealPlan) {
        store.save(plan)
        WidgetCenter.shared.reloadAllTimelines()
        PlanSyncBridge.shared.planDidChange(plan)
        onRemoteChange?()
    }

    /// De systeemvelden van een record, zoals `SyncStateStore` ze bewaart.
    nonisolated fileprivate static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        return archiver.encodedData
    }

    // MARK: - Meedoen aan een gedeelde lijst

    /// Iemand heeft op een uitnodiging getikt.
    ///
    /// Komt binnen via de scene-delegate, bij een warme én een koude start.
    func accept(_ metadata: CKShare.Metadata) async {
        guard CloudAvailability.isEnabled else { return }
        // Tik je op de link van je eigen lijst, dan valt er niets te accepteren.
        guard metadata.participantRole != .owner else {
            Log.sync.info("Eigen uitnodiging geopend, niets te doen")
            return
        }
        do {
            let share = try await container.accept(metadata)
            joined(zoneID: share.recordID.zoneID, share: share)
            Log.sync.info("Uitnodiging geaccepteerd")
        } catch {
            report(error)
        }
    }

    /// Vanaf nu is de lijst van de ander de lijst die de app toont.
    private func joined(zoneID: CKRecordZone.ID, share: CKShare) {
        let wasShared = activeScope == .sharedDatabase && sharedZoneID == zoneID
        sharedZoneID = zoneID
        activeScope = .sharedDatabase
        Preferences.usesSharedList = true
        Preferences.sharedZone = (zoneID.zoneName, zoneID.ownerName)
        remember(share)

        if !wasShared {
            // Je eigen lijst blijft veilig in je eigen zone staan, maar hij mag
            // niet mee de lijst van de ander in.
            adopt(MealPlan(dishes: [], anchorDate: Date(), log: []))
        }
        scheduleFetch()
    }

    /// Onthoudt wie de eigenaar is en of je mag wijzigen.
    private func remember(_ share: CKShare) {
        if let permission = share.currentUserParticipant?.permission, permission != .unknown {
            Preferences.sharedListReadOnly = permission != .readWrite
        }
        Preferences.sharedListOwnerName = Self.displayName(of: share.owner)
        onRemoteChange?()
    }

    /// Haalt bij het opstarten op of je nog meedoet en met welke rechten. De
    /// eigenaar kan dat intussen hebben veranderd, of het delen hebben gestopt.
    private func refreshSharedListDetails() async {
        guard activeScope == .sharedDatabase, let zoneID = sharedZoneID else { return }
        let database = container.sharedCloudDatabase
        do {
            let zone = try await database.recordZone(for: zoneID)
            guard let reference = zone.share,
                  let share = try await database.record(for: reference.recordID) as? CKShare else { return }
            remember(share)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .unknownItem {
            // Alleen bij "bestaat niet meer", nooit bij een netwerkfout: anders
            // zou een slechte verbinding je uit de gedeelde lijst gooien.
            Log.sync.info("Gedeelde lijst bestaat niet meer, terug naar de eigen lijst")
            stoppedUsingSharedList()
        } catch {
            Log.sync.error("Gedeelde lijst niet bijgewerkt: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Een leesbare naam voor een deelnemer, of `nil` als CloudKit die (nog) niet
    /// kent — dat is zo zolang iemand de uitnodiging niet heeft geaccepteerd.
    static func displayName(of participant: CKShare.Participant) -> String? {
        let identity = participant.userIdentity
        if let components = identity.nameComponents {
            let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        }
        return identity.lookupInfo?.emailAddress ?? identity.lookupInfo?.phoneNumber
    }

    /// Of wijzigingen naar iCloud mogen. Wie alleen mag kijken stuurt niets —
    /// CloudKit zou het toch weigeren, en de lijst zou dan lokaal afwijken.
    private var canSend: Bool {
        !(activeScope == .sharedDatabase && Preferences.sharedListReadOnly)
    }

    /// De gedeelde lijst is verlaten: terug naar je eigen lijst.
    ///
    /// Beide engines worden opnieuw opgebouwd met een schone toestand. Dat is
    /// nodig omdat een sync-engine per zone bijhoudt wat hij al heeft gezien; zou
    /// hij die kennis houden, dan haalt hij je eigen gerechten niet opnieuw op en
    /// blijf je met een lege lijst zitten.
    func stoppedUsingSharedList() {
        sharedZoneID = nil
        activeScope = .privateDatabase
        Preferences.forgetSharedList()

        // De lokale planning is nog die van de ander.
        adopt(MealPlan(dishes: [], anchorDate: Date(), log: []))

        for scope in [Scope.privateDatabase, .sharedDatabase] {
            stateStores[scope]?.reset()
            engines[scope] = nil
            delegates[scope] = nil
            makeEngine(for: scope)
        }
        scheduleFetch()
    }

    fileprivate func handleAccountChange(_ changeType: CKSyncEngine.Event.AccountChange.ChangeType) {
        switch changeType {
        case .signIn:
            scheduleFetch()
        case .signOut, .switchAccounts:
            // De records van de vorige gebruiker zeggen niets over de nieuwe.
            for store in stateStores.values { store.reset() }
            sharedZoneID = nil
            activeScope = .privateDatabase
            Preferences.forgetSharedList()
        @unknown default:
            break
        }
    }

    /// Een record dat de server weigerde.
    ///
    /// Twee gevallen mogen niet blijven liggen: dan synchroniseert juist dat ene
    /// gerecht nooit meer terwijl de rest van de lijst gewoon doorloopt, en zien
    /// jullie twee verschillende lijsten zonder dat er iets te zien is.
    fileprivate func retryOrReport(
        _ failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave,
        scope: Scope,
        stateStore: SyncStateStore
    ) {
        let recordID = failure.record.recordID
        switch failure.error.code {
        case .serverRecordChanged:
            // De ander was eerder. Bij een lijstje voor twee wint de laatste
            // schrijver: neem de systeemvelden van de server over, zodat onze
            // versie er alsnog overheen mag.
            guard let server = failure.error.serverRecord else { return report(failure.error) }
            stateStore.setSystemFields(Self.systemFields(of: server), for: recordID.recordName)

        case .unknownItem:
            // Het record bestaat niet meer op de server, maar wel bij ons.
            // Onze systeemvelden wijzen naar iets wat weg is; vergeet ze, dan
            // wordt het record opnieuw aangemaakt. Zo komt een gerecht terug dat
            // 2.0.1 bij het terugzetten uit de geschiedenis weggooide.
            stateStore.setSystemFields(nil, for: recordID.recordName)

        default:
            return report(failure.error)
        }

        Log.sync.info("Record opnieuw aangeboden na \(failure.error.code.rawValue)")
        engines[scope]?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
    }

    fileprivate func report(_ error: Error) {
        Log.sync.error("Synchronisatiefout: \(error.localizedDescription, privacy: .public)")
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
            // De systeemvelden van een verwijderd record wijzen naar iets wat
            // niet meer bestaat. Blijven ze staan, dan botst een record met
            // dezelfde naam dat later opnieuw wordt aangemaakt.
            stateStore.setSystemFields(
                sent.savedRecords.map { ($0.recordID.recordName, CloudSync.systemFields(of: $0)) }
                    + sent.deletedRecordIDs.map { ($0.recordName, nil) }
            )
            for failure in sent.failedRecordSaves {
                await owner.retryOrReport(failure, scope: scope, stateStore: stateStore)
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
