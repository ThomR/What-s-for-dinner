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
        // van andermans wijziging als je de app zelf opent. Zonder de bijbehorende
        // entitlement heeft registreren geen zin.
        if CloudAvailability.isEnabled {
            application.registerForRemoteNotifications()
        }
        return true
    }

    /// De variant met completion-handler en niet de `async`-variant: die laatste
    /// laat een `[AnyHashable: Any]` — niet Sendable — de actorgrens oversteken,
    /// wat in Swift 6 een fout is. Deze wordt op de hoofdactor afgeleverd, net
    /// als de rest van deze delegate, dus er valt niets over te steken.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        Task {
            await CloudSync.shared.fetchChanges()
            completionHandler(.newData)
        }
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
        guard CloudAvailability.isEnabled else { return }
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
