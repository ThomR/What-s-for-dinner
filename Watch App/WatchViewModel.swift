/// ✅ ViewModel voor de Watch-app: ontvangt gerechten van iPhone via WatchConnectivity.
import WatchConnectivity
import os
import SwiftUI

class WatchViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var dishes: [Dish] = []
    @AppStorage("daysInsteadOfNumbers") var daysInsteadOfNumbers: Bool = false
    private var session: WCSession

    override init() {
        self.session = WCSession.default
        super.init()
        loadSavedDishes()
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
                if let daysSetting = message["daysInsteadOfNumbers"] as? Bool {
                    self.daysInsteadOfNumbers = daysSetting
                }
                self.saveDishesLocally()
            } else {
                os_log("⚠️ Geen gerechten ontvangen in bericht", log: .default, type: .info)
            }
        }
    }

    // ✅ Vervang deze verplichte methode zodat die ook gerechten verwerkt
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let dishData = applicationContext["dishes"] as? [[String: String]] {
            DispatchQueue.main.async {
                self.dishes = dishData.compactMap { dict in
                    guard let id = dict["id"], let uuid = UUID(uuidString: id),
                          let name = dict["name"], let emoji = dict["emoji"] else { return nil }
                    return Dish(id: uuid, name: name, emoji: emoji)
                }
                os_log("✅ ApplicationContext gerechten ontvangen", log: .default, type: .info)
                if let daysSetting = applicationContext["daysInsteadOfNumbers"] as? Bool {
                    self.daysInsteadOfNumbers = daysSetting
                }
                self.saveDishesLocally()
            }
        }
    }

    // ✅ Nodig om fouten zoals "WCErrorCodeDeliveryFailed" te voorkomen
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        os_log("ℹ️ didReceiveUserInfo aangeroepen, maar niet gebruikt", log: .default, type: .info)
    }

    private func saveDishesLocally() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(dishes) {
            UserDefaults.standard.set(data, forKey: "watchDishes")
        }
    }

    private func loadSavedDishes() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "watchDishes"),
           let savedDishes = try? decoder.decode([Dish].self, from: data) {
            self.dishes = savedDishes
        }
    }
}
