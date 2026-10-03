import Testing
import Foundation

/// Wat de synchronisatie onthoudt over records die al in iCloud staan.
@Suite("Bewaarde systeemvelden")
struct SyncStandTests {

    private func stand() -> SyncStateStore {
        // Een App Group die in de testbundel niet bestaat: dan blijft alles in
        // het geheugen, en raakt de test het echte bestand niet.
        SyncStateStore(appGroup: "test.syncstand.\(UUID().uuidString)", scope: "test")
    }

    @Test("Een ronde in één keer bewaart en verwijdert per record")
    func rondeInEenKeer() {
        let stand = stand()
        stand.setSystemFields(Data([1]), for: "weg")
        stand.setSystemFields(Data([2]), for: "blijft")

        stand.setSystemFields([
            (recordName: "nieuw", data: Data([3])),
            (recordName: "weg", data: nil)
        ])

        #expect(stand.systemFields(for: "nieuw") == Data([3]))
        #expect(stand.systemFields(for: "weg") == nil)
        #expect(stand.systemFields(for: "blijft") == Data([2]))
    }
}
