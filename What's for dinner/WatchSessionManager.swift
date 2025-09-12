import WatchConnectivity
import os

/// ✅ Singleton die verantwoordelijk is voor communicatie tussen iPhone en Apple Watch via WatchConnectivity.
class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionManager()
    private var session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
    }
    
    /// ✅ Sync gerechten naar de Watch via updateApplicationContext
    func syncDishesToWatch(_ dishes: [Dish]) {
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        do {
            // ✅ Zet de [Dish] array direct om naar Data
            let dishData = try JSONEncoder().encode(dishes)
            let daysSetting = UserDefaults.standard.bool(forKey: "daysInsteadOfNumbers")

            try session.updateApplicationContext([
                "dishesData": dishData, // Verstuur als Data
                "daysInsteadOfNumbers": daysSetting
            ])
        } catch {
            os_log("❌ Fout bij updateApplicationContext: %@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// ✅ Stuur de gerechtenlijst naar de Watch (als directe message)
    func sendDishesToWatch(_ dishes: [Dish]) {
        guard session.isReachable else {
            os_log("⚠️ Watch is niet bereikbaar, probeer via context update.", log: .default, type: .info)
            syncDishesToWatch(dishes) // Fallback naar context update
            return
        }

        do {
            let dishData = try JSONEncoder().encode(dishes)
            let daysSetting = UserDefaults.standard.bool(forKey: "daysInsteadOfNumbers")
            
            session.sendMessage(["dishesData": dishData, "daysInsteadOfNumbers": daysSetting], replyHandler: nil, errorHandler: { error in
                os_log("❌ Fout bij versturen naar Watch: %@", log: .default, type: .error, error.localizedDescription)
            })
        } catch {
            os_log("❌ Fout bij encoden van gerechten voor Watch: %@", log: .default, type: .error, error.localizedDescription)
        }
    }

    /// ✅ Verplichte methodes om activatie-fouten te voorkomen
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            os_log("❌ WatchConnectivity fout: %@", log: .default, type: .error, error.localizedDescription)
        } else {
            os_log("✅ WatchConnectivity geactiveerd op iPhone", log: .default, type: .info)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
