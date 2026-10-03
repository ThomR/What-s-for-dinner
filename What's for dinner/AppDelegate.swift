import UIKit
import CloudKit

/// Nodig voor wat SwiftUI zelf niet aanbiedt: stille pushmeldingen van
/// CloudKit, het koppelen van de scene-delegate die uitnodigingen voor een
/// gedeelde lijst opvangt, en opstartwerk dat niet op een venster mag wachten.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Hier en niet in het eerste scherm. Wijzigt je partner iets, dan start
        // iOS de app met een stille push op de achtergrond, zónder venster. Stond
        // dit in het scherm, dan was er dan geen sync-engine om de wijziging op
        // te halen en niemand om hem naar de Watch te sturen — je zag hem pas
        // als je de app zelf opende. Allebei asynchroon, dus het eerste beeldje
        // wacht er niet op.
        WatchSessionManager.shared.activate()
        PlanSyncBridge.shared.observe { plan in
            WatchSessionManager.shared.send(plan)
        }
        CloudSync.shared.start()

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

    /// Koppelt de scene-delegate, waar iOS uitnodigingen voor een gedeelde lijst
    /// aflevert. SwiftUI bouwt het venster daarna gewoon zelf op.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
