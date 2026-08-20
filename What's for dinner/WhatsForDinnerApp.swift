import SwiftUI

/// Ingang van de app: bouwt de planning op, koppelt de Watch en verwerkt
/// gedeelde JSON-bestanden.
@main
struct DinnerApp: App {
    @StateObject private var store = PlanStore()
    @State private var pendingImport: [Dish]?

    init() {
        Self.configureNavigationBarAppearance()
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    // Elke wijziging van de planning gaat één keer naar de Watch.
                    PlanSyncBridge.shared.observe { plan in
                        WatchSessionManager.shared.send(plan)
                    }
                    WatchSessionManager.shared.send(store.plan)
                }
                .onOpenURL(perform: handleIncomingFile)
                .alert(
                    LocalizedStringKey("import_alert_title"),
                    isPresented: .init(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                    presenting: pendingImport
                ) { dishes in
                    Button(LocalizedStringKey("import_replace"), role: .destructive) {
                        store.replaceAll(with: dishes)
                        pendingImport = nil
                    }
                    Button(LocalizedStringKey("cancel"), role: .cancel) {
                        pendingImport = nil
                    }
                } message: { dishes in
                    Text(LocalizedStringKey("import_alert_message \(dishes.count)"))
                }
        }
    }

    /// Leest een gedeelde lijst in. Vervangt de planning niet meteen: dat gooit
    /// weg wat er stond, dus daar hoort een bevestiging bij.
    private func handleIncomingFile(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), let dishes = DishListExport.read(data) else {
            Log.store.error("Gedeeld bestand kon niet gelezen worden")
            return
        }
        pendingImport = dishes
    }

    private static func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()

        let largeTitleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        if let descriptor = largeTitleFont.fontDescriptor.withDesign(.rounded)?.withSymbolicTraits(.traitBold) {
            appearance.largeTitleTextAttributes[.font] = UIFont(descriptor: descriptor, size: largeTitleFont.pointSize)
        }

        let inlineTitleFont = UIFont.preferredFont(forTextStyle: .headline)
        if let descriptor = inlineTitleFont.fontDescriptor.withDesign(.rounded)?.withSymbolicTraits(.traitBold) {
            appearance.titleTextAttributes[.font] = UIFont(descriptor: descriptor, size: inlineTitleFont.pointSize)
        }

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}
