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

    /// ✅ Stuur de gerechtenlijst naar de Watch
    func sendDishesToWatch(_ dishes: [Dish]) {
        guard session.isReachable else {
            os_log("⚠️ Watch is niet bereikbaar", log: .default, type: .info)
            return
        }

        let dishData: [[String: String]] = dishes.map { ["id": $0.id.uuidString, "name": $0.name, "emoji": $0.emoji] }
        session.sendMessage(["dishes": dishData], replyHandler: nil, errorHandler: { error in
            os_log("❌ Fout bij versturen naar Watch: %@", log: .default, type: .error, error.localizedDescription)
        })
    }

    /// ✅ Watch vraagt gerechten op
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["requestDishes"] as? Bool == true {
            DispatchQueue.main.async {
                // Dit is alleen voor testdoeleinden; overweeg dependency injection te gebruiken.
                let dishes = DishesViewModel().dishes
                self.sendDishesToWatch(dishes)
            }
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
