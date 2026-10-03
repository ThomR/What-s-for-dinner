import SwiftUI

/// Ingang van de app: bouwt de planning op, koppelt de Watch en verwerkt
/// gedeelde JSON-bestanden.
@main
struct DinnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PlanStore()
    @State private var pendingImport: [Dish]?

    init() {
        Self.configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    // Synchronisatie en Watch-sessie zijn al gestart in de
                    // AppDelegate. Hier alleen wat het scherm aangaat.
                    WatchSessionManager.shared.send(store.plan)

                    // Komt er iets uit iCloud binnen, dan werkt het scherm bij.
                    // Eén keer meteen ophalen: de sync draaide al vóór dit
                    // scherm er was en kan iets hebben binnengehaald.
                    CloudSync.shared.onRemoteChange = {
                        store.adoptRemoteChanges()
                    }
                    store.adoptRemoteChanges()
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
