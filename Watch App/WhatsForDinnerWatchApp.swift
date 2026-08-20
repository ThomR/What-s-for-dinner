import SwiftUI

@main
struct WhatsForDinnerWatchApp: App {
    @StateObject private var store = PlanStore()

    var body: some Scene {
        WindowGroup {
            WatchAppView()
                .environmentObject(store)
                .task {
                    WatchPlanReceiver.shared.onUpdate = {
                        Task { @MainActor in store.refresh() }
                    }
                    WatchPlanReceiver.shared.activate()
                }
        }
    }
}
