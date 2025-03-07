import SwiftUI

@main
struct DinnerApp: App {
    @StateObject private var viewModel = DishesViewModel()
    @StateObject private var dateTracker = DateTracker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(dateTracker)
                .onOpenURL { url in
                    handleIncomingJSON(url: url)
                }
        }
    }

    private func handleIncomingJSON(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Geen toegang tot het gedeelde bestand.")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() } // Zorg ervoor dat we de toegang weer afsluiten

        do {
            let data = try Data(contentsOf: url)
            DispatchQueue.main.async {
                viewModel.importDishes(from: data) // ✅ Gebruik verbeterde importfunctie
            }
        } catch {
            print("❌ Fout bij het verwerken van het gedeelde JSON-bestand: \(error.localizedDescription)")
        }
    }
}
