import Foundation

/// Doorgeefluik tussen de planning en alles wat hem verder moet verspreiden:
/// de Apple Watch en straks iCloud.
///
/// Een losse haak in plaats van een rechtstreekse aanroep, zodat deze laag niets
/// hoeft te weten van WatchConnectivity of CloudKit — die frameworks bestaan niet
/// in elke extensie waarin deze code meecompileert.
@MainActor
final class PlanSyncBridge {
    static let shared = PlanSyncBridge()

    private var observers: [(MealPlan) -> Void] = []

    private init() {}

    /// Meld je aan bij het opstarten van de app.
    func observe(_ handler: @escaping (MealPlan) -> Void) {
        observers.append(handler)
    }

    func planDidChange(_ plan: MealPlan) {
        for observer in observers {
            observer(plan)
        }
    }
}

/// De sleutel waaronder de planning tussen iPhone en Watch reist. Staat hier
/// omdat beide kanten hem nodig hebben.
enum PlanTransfer {
    static let key = "mealPlan"
}
