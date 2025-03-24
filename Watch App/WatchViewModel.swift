/// ✅ ViewModel voor de Watch-app: ontvangt gerechten van iPhone via WatchConnectivity.
import WatchConnectivity
import os

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var dishes: [Dish] = []
    private var session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        session.delegate = self
        
        if WCSession.default.activationState == .notActivated {
            session.activate() // ✅ Zorg dat de sessie geactiveerd wordt
        }
        
        if session.isReachable {
            session.sendMessage(["requestDishes": true], replyHandler: nil, errorHandler: { error in
                os_log("❌ Fout bij requestDishes: %@", log: .default, type: .error, error.localizedDescription)
            })
        }
    }

    // ✅ Verplichte delegate-methodes
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error = error {
            os_log("❌ WatchConnectivity fout: %@", log: .default, type: .error, error.localizedDescription)
        } else {
            os_log("✅ WatchConnectivity geactiveerd", log: .default, type: .info)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let dishData = message["dishes"] as? [[String: String]] {
                self.dishes = dishData.compactMap { dict in
                    guard let id = dict["id"], let uuid = UUID(uuidString: id),
                          let name = dict["name"], let emoji = dict["emoji"] else { return nil }
                    return Dish(id: uuid, name: name, emoji: emoji)
                }
                os_log("✅ Gerechten ontvangen op Watch: %@", log: .default, type: .info, self.dishes)
            } else {
                os_log("⚠️ Geen gerechten ontvangen in bericht", log: .default, type: .info)
            }
        }
    }

    // ✅ Voeg deze verplichte methode toe, zelfs als deze niet wordt gebruikt
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        os_log("ℹ️ didReceiveApplicationContext aangeroepen, maar niet gebruikt", log: .default, type: .info)
    }

    // ✅ Nodig om fouten zoals "WCErrorCodeDeliveryFailed" te voorkomen
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        os_log("ℹ️ didReceiveUserInfo aangeroepen, maar niet gebruikt", log: .default, type: .info)
    }
}
