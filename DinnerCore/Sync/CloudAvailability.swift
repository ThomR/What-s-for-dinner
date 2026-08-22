import Foundation

/// Of deze build überhaupt met iCloud mag praten.
///
/// Er is één schakelaar, `DINNER_CLOUDKIT`, die twee dingen tegelijk regelt: het
/// entitlements-bestand waarmee de app ondertekend wordt, en deze vlag in
/// `Info.plist`. Dat moet één schakelaar zijn, want de twee mogen nooit uit
/// elkaar lopen: zonder de entitlement stopt `CKContainer(identifier:)` het
/// programma bij de eerste aanraking — het gooit geen fout die op te vangen is.
enum CloudAvailability {
    static let isEnabled: Bool = {
        // Extensies hebben hun eigen Info.plist zonder deze sleutel; die
        // synchroniseren niet en lezen alleen wat de app heeft opgeslagen.
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DinnerCloudKit") as? String else {
            return false
        }
        return value == "YES"
    }()
}
