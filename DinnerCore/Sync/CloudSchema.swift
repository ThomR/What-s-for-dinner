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

    /// Hoe een record heet in iCloud.
    ///
    /// Een gerecht en zijn logregel houden met opzet dezelfde `id`: streept de
    /// app op twee toestellen om middernacht hetzelfde gerecht af, dan is dat
    /// daardoor één logregel en niet twee. In iCloud mogen ze diezelfde naam
    /// juist *niet* delen. Een record heeft één type, en een naam die van
    /// `Dish` naar `ServedMeal` verhuist levert in één keer een bewaar- én een
    /// verwijderopdracht voor hetzelfde record op. CloudKit houdt daar maar één
    /// van over, en in 2.0.1 was dat bij terugzetten uit de geschiedenis de
    /// verwijdering — het gerecht verdween dan bij je partner terwijl het bij
    /// jou op de lijst bleef staan.
    enum RecordName {
        /// Logregels staan onder een eigen naam. Gerechten houden de blote
        /// uuid, zodat records die er al staan niet opnieuw hoeven.
        static let mealPrefix = "served-"

        static func dish(_ id: UUID) -> String { id.uuidString }
        static func meal(_ id: UUID) -> String { mealPrefix + id.uuidString }

        enum Kind: Equatable {
            case plan
            case dish(UUID)
            case meal(UUID)
        }

        /// Waar een recordnaam over gaat. `nil` bij een naam die we niet kennen.
        ///
        /// Een blote uuid is een gerecht. Logregels van vóór deze versie staan
        /// ook onder een blote uuid; die zijn alleen aan hun recordtype te
        /// herkennen, niet aan hun naam.
        static func kind(of recordName: String) -> Kind? {
            if recordName == planRecordName { return .plan }
            if recordName.hasPrefix(mealPrefix) {
                return UUID(uuidString: String(recordName.dropFirst(mealPrefix.count))).map(Kind.meal)
            }
            return UUID(uuidString: recordName).map(Kind.dish)
        }

        /// Welke records er bij een lokale wijziging naar iCloud moeten.
        ///
        /// Staat hier en niet in `CloudSync`, zodat de regel waar het in 2.0.1
        /// op misging te testen is zonder iCloud: dezelfde naam mag nooit in
        /// beide lijsten staan.
        static func records(for changes: PlanChanges) -> (save: [String], delete: [String]) {
            var save = changes.changedDishes.map(dish) + changes.changedMeals.map(meal)
            let delete = changes.removedDishes.map(dish) + changes.removedMeals.map(meal)
            // De volgorde staat in het plan-record, dus dat moet ook mee zodra
            // er een gerecht bij komt of verdwijnt.
            if changes.metadataChanged || !changes.changedDishes.isEmpty || !changes.removedDishes.isEmpty {
                save.append(planRecordName)
            }
            return (save, delete)
        }
    }
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

    /// Leest een logregel. `id` komt niet uit de recordnaam maar van buiten:
    /// logregels staan onder hun eigen naam (`served-<uuid>`), en records van
    /// vóór deze versie onder de blote uuid van het gerecht.
    init?(record: CKRecord, id: UUID) {
        guard record.recordType == CloudSchema.RecordType.meal,
              let name = record[CloudSchema.Field.name] as? String,
              let emoji = record[CloudSchema.Field.emoji] as? String,
              let servedOn = record[CloudSchema.Field.servedOn] as? Date
        else { return nil }
        self.init(id: id, name: name, emoji: emoji, servedOn: servedOn)
    }
}
#endif
