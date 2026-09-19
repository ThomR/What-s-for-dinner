import UIKit
import CloudKit

/// Toont het systeemvenster om iemand uit te nodigen.
///
/// Bewust rechtstreeks via UIKit en niet als SwiftUI-sheet.
/// `UICloudSharingController` regelt zijn eigen presentatie en sluit zichzelf;
/// in een `.sheet` verpakt nam hij het scherm eronder mee naar buiten, waardoor
/// je meteen terug was bij de lijst.
@MainActor
enum CloudSharingPresenter {

    /// De delegate wordt zwak vastgehouden door de controller, dus hier houden
    /// we hem vast zolang het venster open staat.
    private static var activeDelegate: Delegate?

    static func present(share: CKShare, container: CKContainer, onChange: @escaping () -> Void) {
        guard let host = topViewController() else {
            Log.sync.error("Geen scherm gevonden om het deelvenster op te tonen")
            return
        }

        let delegate = Delegate(onChange: onChange)
        activeDelegate = delegate

        let controller = UICloudSharingController(share: share, container: container)
        // Kijken én wijzigen aanbieden, zodat de eigenaar per persoon kiest.
        controller.availablePermissions = [.allowReadWrite, .allowReadOnly, .allowPrivate]
        controller.delegate = delegate
        host.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private final class Delegate: NSObject, UICloudSharingControllerDelegate {
        private let onChange: () -> Void

        init(onChange: @escaping () -> Void) {
            self.onChange = onChange
        }

        func itemTitle(for controller: UICloudSharingController) -> String? {
            String(localized: "share_list_title")
        }

        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Log.sync.error("Uitnodiging niet opgeslagen: \(error.localizedDescription, privacy: .public)")
            finish()
        }

        func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
            CloudSync.shared.scheduleFetch()
            finish()
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            CloudSync.shared.scheduleFetch()
            finish()
        }

        private func finish() {
            onChange()
            CloudSharingPresenter.activeDelegate = nil
        }
    }
}
