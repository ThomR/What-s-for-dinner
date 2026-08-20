import SwiftUI

/// Hoofdscherm: de wachtrij met gerechten, met toevoegen, bewerken, afstrepen,
/// slepen en delen.
struct ContentView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var editorMode: DishEditorView.Mode?
    @State private var showResetAlert = false
    @State private var showSettings = false
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ZStack {
                if store.isEmpty {
                    emptyStateView
                } else {
                    dishesListView
                }
                VStack {
                    Spacer()
                    FloatingButtons(onAdd: { editorMode = .add })
                        .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
            .toolbar { toolbarContent }
            .sheet(item: $editorMode) { mode in
                DishEditorView(mode: mode) { name in
                    switch mode {
                    case .add: store.add(name: name)
                    case .edit(let dish): store.rename(dish, to: name)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [DishListActivityItemSource(fileURL: item.url)])
            }
            .alert(LocalizedStringKey("reset_alert_title"), isPresented: $showResetAlert) {
                Button(LocalizedStringKey("yes"), role: .destructive) {
                    withAnimation { store.clearQueue() }
                }
                Button(LocalizedStringKey("cancel"), role: .cancel) {}
            }
            .onChange(of: scenePhase) { _, phase in
                // De dag kan verstreken zijn terwijl de app op de achtergrond stond.
                if phase == .active { store.refresh() }
            }
            .task {
                // Het systeem meldt zelf wanneer de dag omslaat — betrouwbaarder
                // dan een timer, die niet vuurt zolang de app geschorst is.
                for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                    store.refresh()
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("empty_state_message"), systemImage: "fork.knife")
                .fontDesign(.rounded)
        }
    }

    private var dishesListView: some View {
        List {
            ForEach(store.scheduled) { item in
                DishRow(item: item, now: store.today)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            editorMode = .edit(item.dish)
                        } label: {
                            Label(LocalizedStringKey("edit"), systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            withAnimation { store.serve(item.dish) }
                        } label: {
                            Label(LocalizedStringKey("clear"), systemImage: "checkmark")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            withAnimation { store.remove(item.dish) }
                        } label: {
                            Label(LocalizedStringKey("delete"), systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                store.move(fromOffsets: source, toOffset: destination)
            }
        }
        .listStyle(.plain)
        .animation(.default, value: store.scheduled)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .accessibilityLabel(LocalizedStringKey("settings_title"))

            Menu {
                Button {
                    shareItem = DishListExport.write(store.plan.dishes).map(ShareItem.init)
                } label: {
                    Label(LocalizedStringKey("share"), systemImage: "square.and.arrow.up")
                }
                .disabled(store.isEmpty)

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label(LocalizedStringKey("reset"), systemImage: "trash")
                }
                .disabled(store.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel(LocalizedStringKey("more_actions"))
        }
    }
}

/// Zodat `.sheet(item:)` op de bewerkmodus kan werken.
extension DishEditorView.Mode: Identifiable {
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let dish): return dish.id.uuidString
        }
    }
}

/// Een gedeeld bestand, zodat `.sheet(item:)` er een identiteit voor heeft.
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    ContentView().environmentObject(PlanStore())
}
