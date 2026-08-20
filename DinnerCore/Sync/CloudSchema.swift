import Foundation

#if canImport(CloudKit)
import CloudKit
#endif

/// Hoe de planning eruitziet in iCloud.
enum CloudSchema {
    /// De container. Moet in het Apple Developer-portaal bestaan en in de
    /// entitlements van de app staan.
    static let containerIdentifier = "iCloud.nl.whatsfordinner.app"

    /// Alles staat in één eigen zone. Dat is nodig om te kunnen delen: een
    /// uitnodiging deelt de hele zone, dus je partner ziet meteen de complete
    /// lijst en alles wat er later bij komt.
    static let zoneName = "MealPlan"

    enum RecordType {
        static let dish = "Dish"
        static let meal = "ServedMeal"
        static let plan = "Plan"
    }

    enum Field {
        static let name = "name"
        static let emoji = "emoji"
        static let addedAt = "addedAt"
        static let servedOn = "servedOn"
        static let anchorDate = "anchorDate"
        static let order = "order"
    }

    /// Er is precies één plan-record per zone, met een vaste naam zodat beide
    /// kanten hetzelfde record bijwerken in plaats van er twee te maken.
    static let planRecordName = "plan"
}

#if canImport(CloudKit)
extension Dish {
    /// Schrijft het gerecht in een record, met behoud van de systeemvelden die
    /// er al in staan.
    func write(to record: CKRecord) {
        record[CloudSchema.Field.name] = name as CKRecordValue
        record[CloudSchema.Field.emoji] = emoji as CKRecordValue
        record[CloudSchema.Field.addedAt] = addedAt as CKRecordValue
    }

    /// Leest een gerecht uit een record. `nil` als het record niet compleet is —
    /// een half gerecht in de lijst is erger dan geen.
    init?(record: CKRecord) {
        guard record.recordType == CloudSchema.RecordType.dish,
              let id = UUID(uuidString: record.recordID.recordName),
              let name = record[CloudSchema.Field.name] as? String,
              let emoji = record[CloudSchema.Field.emoji] as? String
        else { return nil }
        self.init(
            id: id,
            name: name,
            emoji: emoji,
            addedAt: record[CloudSchema.Field.addedAt] as? Date ?? Date()
        )
    }
}

extension ServedMeal {
    func write(to record: CKRecord) {
        record[CloudSchema.Field.name] = name as CKRecordValue
        record[CloudSchema.Field.emoji] = emoji as CKRecordValue
        record[CloudSchema.Field.servedOn] = servedOn as CKRecordValue
    }

    init?(record: CKRecord) {
        guard record.recordType == CloudSchema.RecordType.meal,
              let id = UUID(uuidString: record.recordID.recordName),
              let name = record[CloudSchema.Field.name] as? String,
              let emoji = record[CloudSchema.Field.emoji] as? String,
              let servedOn = record[CloudSchema.Field.servedOn] as? Date
        else { return nil }
        self.init(id: id, name: name, emoji: emoji, servedOn: servedOn)
    }
}
#endif
