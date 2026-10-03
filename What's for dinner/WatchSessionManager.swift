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

    /// Wat er verstuurd moest worden voordat de sessie klaar was. Alleen op de
    /// hoofdthread aanraken.
    ///
    /// Activeren gaat asynchroon. Een planning die in dat gaatje werd verstuurd
    /// — bij het opstarten, of na een push op de achtergrond — ging verloren, en
    /// dan bleef de Watch op de vorige lijst staan.
    private var pending: MealPlan?

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
        guard let session else { return }
        guard session.activationState == .activated else {
            pending = plan
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        // Zonder logboek. De Watch toont het nergens, en het groeit elke dag:
        // na een jaar of anderhalf zou de planning niet meer in een
        // applicationContext passen en kreeg de Watch helemaal niets meer.
        let forWatch = MealPlan(dishes: plan.dishes, anchorDate: plan.anchorDate, log: [])

        do {
            let payload: [String: Any] = [
                PlanTransfer.key: try JSONEncoder.plan.encode(forWatch),
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
        guard state == .activated else { return }
        DispatchQueue.main.async {
            guard let plan = self.pending else { return }
            self.pending = nil
            self.send(plan)
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
        DispatchQueue.main.async {
            self.send(DishStore.phoneStore.load())
        }
    }
}
