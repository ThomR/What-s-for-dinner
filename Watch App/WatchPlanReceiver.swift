import WatchConnectivity
import WidgetKit
import Foundation

/// Ontvangt de planning van de iPhone en bewaart hem lokaal.
///
/// Eén exemplaar, één sessiedelegate. Eerder maakten de app en de hoofdweergave
/// er allebei één aan; de laatste won en de andere luisterde nergens naar.
final class WatchPlanReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchPlanReceiver()

    /// Wordt aangeroepen zodra er nieuwe gegevens binnen zijn.
    var onUpdate: (@Sendable () -> Void)?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error {
            Log.watch.error("Activeren mislukt: \(error.localizedDescription, privacy: .public)")
            return
        }
        // Bij het opstarten staat de laatst verstuurde context al klaar.
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    // MARK: - Verwerken

    private func apply(_ payload: [String: Any]) {
        // Instellingen ook overnemen als er geen planning bij zit: de gebruiker kan
        // alleen een schakelaar hebben omgezet.
        if let showsDayLabels = payload[Preferences.Key.showsDayLabels] as? Bool {
            Preferences.showsDayLabels = showsDayLabels
        }
        if let autoAdvance = payload[Preferences.Key.autoAdvance] as? Bool {
            Preferences.autoAdvance = autoAdvance
        }

        guard let data = payload[PlanTransfer.key] as? Data else { return }
        guard let plan = try? JSONDecoder.plan.decode(MealPlan.self, from: data) else {
            Log.watch.error("Ontvangen planning kon niet gelezen worden")
            return
        }

        DishStore.watchStore.save(plan)
        WidgetCenter.shared.reloadAllTimelines()
        onUpdate?()
        Log.watch.info("Planning ontvangen: \(plan.dishes.count) gerechten")
    }
}
