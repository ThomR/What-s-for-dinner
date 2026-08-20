import UIKit
import CloudKit

/// Nodig voor twee dingen die SwiftUI zelf niet aanbiedt: stille pushmeldingen
/// van CloudKit, en het accepteren van een uitnodiging voor een gedeelde lijst.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Zonder registratie stuurt CloudKit geen meldingen en merk je pas iets
        // van andermans wijziging als je de app zelf opent.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            return .noData
        }
        await CloudSync.shared.fetchChanges()
        return .newData
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.sync.error("Pushregistratie mislukt: \(error.localizedDescription, privacy: .public)")
    }

    /// Iemand tikt op de uitnodiging die je hebt gestuurd.
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task {
            do {
                _ = try await CloudSharing.container.accept(metadata)
                await CloudSync.shared.fetchChanges()
                Log.sync.info("Uitnodiging geaccepteerd")
            } catch {
                Log.sync.error("Uitnodiging niet geaccepteerd: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
