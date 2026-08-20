import Foundation

#if canImport(CloudKit) && os(iOS)
import CloudKit

/// Het uitnodigen van iemand anders voor je lijst.
///
/// De hele zone wordt gedeeld, niet losse gerechten: je partner ziet daarmee de
/// complete lijst, inclusief alles wat er later bij komt, zonder dat er per
/// gerecht iets geregeld hoeft te worden.
@available(iOS 17.0, *)
enum CloudSharing {

    static let container = CKContainer(identifier: CloudSchema.containerIdentifier)

    enum SharingError: LocalizedError {
        case notSignedIn
        case alreadyParticipant

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return String(localized: "share_error_no_icloud")
            case .alreadyParticipant:
                return String(localized: "share_error_already_shared")
            }
        }
    }

    /// De uitnodiging voor je eigen lijst; maakt hem aan als die er nog niet is.
    static func shareForOwnList() async throws -> CKShare {
        guard try await container.accountStatus() == .available else {
            throw SharingError.notSignedIn
        }
        // Wie zelf al deelnemer is aan andermans lijst, kan die niet nog eens
        // doorverdelen — dat zou twee lijsten tegelijk betekenen.
        if await CloudSync.shared.activeScope == .sharedDatabase {
            throw SharingError.alreadyParticipant
        }

        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: CloudSchema.zoneName, ownerName: CKCurrentUserDefaultName)

        // De zone moet bestaan voordat er een uitnodiging voor gemaakt kan worden.
        _ = try? await database.save(CKRecordZone(zoneID: zoneID))

        if let existing = try await existingShare(in: database, zoneID: zoneID) {
            return existing
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = String(localized: "share_list_title")
        share.publicPermission = .none

        let result = try await database.modifyRecords(saving: [share], deleting: [])
        for (_, saveResult) in result.saveResults {
            if case .success(let record) = saveResult, let saved = record as? CKShare {
                return saved
            }
        }
        return share
    }

    /// De bestaande uitnodiging, als je er al een hebt gemaakt.
    static func existingShareIfAny() async throws -> CKShare? {
        guard try await container.accountStatus() == .available else { return nil }
        let zoneID = CKRecordZone.ID(zoneName: CloudSchema.zoneName, ownerName: CKCurrentUserDefaultName)
        return try await existingShare(in: container.privateCloudDatabase, zoneID: zoneID)
    }

    private static func existingShare(in database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> CKShare? {
        guard let zone = try? await database.recordZone(for: zoneID), let shareReference = zone.share else {
            return nil
        }
        return try? await database.record(for: shareReference.recordID) as? CKShare
    }

    /// Stopt met delen. De ander houdt niets over — het was jouw lijst.
    static func stopSharing() async throws {
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: CloudSchema.zoneName, ownerName: CKCurrentUserDefaultName)
        guard let zone = try? await database.recordZone(for: zoneID), let shareReference = zone.share else { return }
        _ = try await database.modifyRecords(saving: [], deleting: [shareReference.recordID])
    }

    /// Verlaat de lijst van iemand anders.
    static func leaveSharedList() async throws {
        guard let zoneID = await CloudSync.shared.sharedZoneID else { return }
        _ = try await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
    }
}
#endif
