import SwiftUI
import WatchConnectivity
import os

/// ✅ Hoofdingang van de app: initialiseert ViewModels, beheert Watch-connectie, en verwerkt gedeelde JSON-bestanden.
@main
struct DinnerApp: App {
    @Environment(\.scenePhase) private var scenePhase // Monitor de app status
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false
    @StateObject private var viewModel = DishesViewModel()
    @StateObject private var dateTracker = DateTracker()
    private let watchSessionManager = WatchSessionManager.shared  // ✅ Zorgt ervoor dat WatchSessionManager actief blijft

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(dateTracker)
                .onOpenURL { url in
                    handleIncomingJSON(url: url)
                }
                .task {
                    watchSessionManager.sendDishesToWatch(viewModel.dishes) // ✅ Stuur gerechten naar de Watch bij opstarten
                }
                .onChange(of: viewModel.dishes) {
                    watchSessionManager.sendDishesToWatch(viewModel.dishes) // ✅ Stuur updates naar de Watch
                }
                .onChange(of: daysInsteadOfNumbers) {
                    watchSessionManager.syncDishesToWatch(viewModel.dishes)
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        viewModel.autoCompleteTopDishIfNeeded()
                    }
                }
        }
    }

    private func handleIncomingJSON(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            os_log("❌ Geen toegang tot het gedeelde bestand.", log: .default, type: .error)
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            DispatchQueue.main.async {
                viewModel.importDishes(from: data)
                watchSessionManager.sendDishesToWatch(viewModel.dishes) // ✅ Zorg dat de Watch ook de nieuwe gerechten krijgt
            }
        } catch {
            os_log("❌ Fout bij JSON-verwerking: %@", log: .default, type: .error, error.localizedDescription)
        }
    }
}
