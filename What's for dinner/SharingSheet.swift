import SwiftUI
import CloudKit

/// Het systeemvenster om iemand uit te nodigen voor je lijst.
struct SharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for controller: UICloudSharingController) -> String? {
            String(localized: "share_list_title")
        }

        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Log.sync.error("Uitnodiging niet opgeslagen: \(error.localizedDescription, privacy: .public)")
        }

        func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
            CloudSync.shared.scheduleFetch()
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            CloudSync.shared.scheduleFetch()
        }
    }
}
