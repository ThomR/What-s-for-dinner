/// ✅ Entry point voor de watchOS-app: initialiseert ViewModel en activeert WatchConnectivity indien nodig.
import SwiftUI
import WatchConnectivity

@main
struct WhatsForDinnerWatchApp: App {
    @StateObject private var watchViewModel = WatchViewModel() // ✅ WatchOS ViewModel

    init() {
        if WCSession.default.activationState == .notActivated {
            WCSession.default.activate() // ✅ Activeer de WatchConnectivity sessie
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchAppView()
                .environmentObject(watchViewModel)
        }
    }
}
