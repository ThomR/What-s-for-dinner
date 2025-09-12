/// ✅ ViewModel voor de Watch-app: ontvangt gerechten van iPhone via WatchConnectivity.
import WatchConnectivity
import os
import SwiftUI
import WidgetKit

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
            session.activate()
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
        handleReceivedData(from: message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleReceivedData(from: applicationContext)
    }
    
    // ✅ Generieke functie om zowel Message als ApplicationContext af te handelen
    private func handleReceivedData(from dictionary: [String: Any]) {
        if let dishData = dictionary["dishesData"] as? Data {
            DispatchQueue.main.async {
                if let decodedDishes = try? JSONDecoder().decode([Dish].self, from: dishData) {
                    self.dishes = decodedDishes
                    os_log("✅ Gerechten succesvol ontvangen en gedecodeerd op Watch.", log: .default, type: .info)
                    self.saveDishesLocally() // Sla direct op na ontvangen
                }
                if let daysSetting = dictionary["daysInsteadOfNumbers"] as? Bool {
                    self.daysInsteadOfNumbers = daysSetting
                }
            }
        }
    }

    private func saveDishesLocally() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(dishes) {
            let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.watchshared")
            userDefaults?.set(data, forKey: "watchDishes")
            
            // 🔥 Forceer widget refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func loadSavedDishes() {
        let decoder = JSONDecoder()
        let userDefaults = UserDefaults(suiteName: "group.whatsfordinner.watchshared")
        if let data = userDefaults?.data(forKey: "watchDishes"),
           let savedDishes = try? decoder.decode([Dish].self, from: data) {
            self.dishes = savedDishes
        }
    }
}
