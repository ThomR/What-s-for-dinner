import Foundation

/// Bewaart wat de synchronisatie tussen twee sessies moet onthouden: de eigen
/// toestand van de sync-engine en de systeemvelden van records die al in iCloud
/// staan.
///
/// Die systeemvelden zijn geen bijzaak. Zonder de bewaarde `recordChangeTag`
/// denkt CloudKit bij elke wijziging dat je een nieuw record aanmaakt, en dan
/// krijg je conflicten op records die allang bestaan.
final class SyncStateStore: @unchecked Sendable {

    private let directory: URL?
    private let queue = DispatchQueue(label: "nl.whatsfordinner.syncstate")
    private var systemFieldsCache: [String: Data]?

    /// `scope` scheidt de privédatabase van de gedeelde: het zijn twee losse
    /// engines met elk hun eigen toestand.
    private let scope: String

    init(appGroup: String = DishStore.Group.phone, scope: String) {
        self.scope = scope
        self.directory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("Sync", isDirectory: true)
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Toestand van de sync-engine

    private var stateURL: URL? {
        directory?.appendingPathComponent("state-\(scope).bin")
    }

    func loadState() -> Data? {
        guard let stateURL else { return nil }
        return try? Data(contentsOf: stateURL)
    }

    func saveState(_ data: Data?) {
        guard let stateURL else { return }
        do {
            if let data {
                try data.write(to: stateURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: stateURL)
            }
        } catch {
            Log.sync.error("Synchronisatiestand niet bewaard: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Systeemvelden per record

    private var systemFieldsURL: URL? {
        directory?.appendingPathComponent("records-\(scope).json")
    }

    private func loadSystemFields() -> [String: Data] {
        if let systemFieldsCache { return systemFieldsCache }
        guard let systemFieldsURL,
              let data = try? Data(contentsOf: systemFieldsURL),
              let stored = try? JSONDecoder().decode([String: Data].self, from: data)
        else {
            systemFieldsCache = [:]
            return [:]
        }
        systemFieldsCache = stored
        return stored
    }

    private func persistSystemFields(_ fields: [String: Data]) {
        systemFieldsCache = fields
        guard let systemFieldsURL else { return }
        try? JSONEncoder().encode(fields).write(to: systemFieldsURL, options: .atomic)
    }

    func systemFields(for recordName: String) -> Data? {
        queue.sync { loadSystemFields()[recordName] }
    }

    /// De namen van alle records waarvan we weten dat ze in iCloud staan.
    func knownRecordNames() -> [String] {
        queue.sync { Array(loadSystemFields().keys) }
    }

    func setSystemFields(_ data: Data?, for recordName: String) {
        setSystemFields([(recordName, data)])
    }

    /// Een hele ronde in één keer. Elke wijziging herschrijft het hele bestand,
    /// en een ophaalronde levert er soms honderden tegelijk: de eerste keer na
    /// het meedoen aan een lijst, of de eenmalige reparatie in 2.0.2. Per record
    /// schrijven was dan honderden keer een steeds groter bestand.
    ///
    /// Een lijst van paren en geen woordenboek: `nil` in een `[String: Data?]`
    /// zetten haalt de sleutel weg in plaats van "verwijder dit" te bewaren.
    func setSystemFields(_ updates: [(recordName: String, data: Data?)]) {
        guard !updates.isEmpty else { return }
        queue.sync {
            var fields = loadSystemFields()
            for update in updates {
                fields[update.recordName] = update.data
            }
            persistSystemFields(fields)
        }
    }

    /// Alles vergeten. Nodig bij het wisselen van iCloud-account: de records van
    /// de vorige gebruiker zeggen niets meer over de nieuwe.
    func reset() {
        queue.sync {
            persistSystemFields([:])
            saveState(nil)
        }
    }
}
