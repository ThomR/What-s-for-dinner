import WatchConnectivity
import Foundation

/// Stuurt de planning naar de Apple Watch.
///
/// Eén verzendpad in plaats van twee. `updateApplicationContext` is de basis: dat
/// blijft in de wachtrij staan tot de Watch bereikbaar is, ook als die nu uit
/// staat. Is de Watch wél bereikbaar, dan gaat er daarnaast een bericht heen
/// zodat het scherm meteen klopt.
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    private override init() {
        super.init()
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    func send(_ plan: MealPlan) {
        guard let session, session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        do {
            let payload: [String: Any] = [
                PlanTransfer.key: try JSONEncoder.plan.encode(plan),
                Preferences.Key.showsDayLabels: Preferences.showsDayLabels,
                Preferences.Key.autoAdvance: Preferences.autoAdvanceSetting
            ]
            try session.updateApplicationContext(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil) { error in
                    // Geen ramp: de context staat al klaar en komt alsnog aan.
                    Log.watch.info("Bericht niet bezorgd: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            Log.watch.error("Versturen mislukt: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            Log.watch.error("Activeren mislukt: \(error.localizedDescription, privacy: .public)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Er is van Watch gewisseld; opnieuw activeren voor het nieuwe apparaat.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Watch-app net geïnstalleerd of gekoppeld: stuur meteen wat we hebben.
        guard session.isPaired, session.isWatchAppInstalled else { return }
        let plan = DishStore.phoneStore.load()
        send(plan)
    }
}
