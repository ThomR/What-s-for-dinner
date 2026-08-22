import SwiftUI

/// Hoofdscherm: de wachtrij met gerechten, met toevoegen, bewerken, afstrepen,
/// slepen en delen.
struct ContentView: View {
    @EnvironmentObject private var store: PlanStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var editorMode: DishEditorView.Mode?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isEmpty {
                    emptyStateView
                } else {
                    dishesListView
                }
            }
            // Als inset en niet als laag eroverheen: zo kan het laatste gerecht
            // langs de knop scrollen in plaats van eronder te verdwijnen.
            .safeAreaInset(edge: .bottom) {
                FloatingActionBar(
                    onAdd: { editorMode = .add },
                    onSettings: { showSettings = true }
                )
                .padding(.bottom, 8)
            }
            .navigationTitle(LocalizedStringKey("title"))
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
            #if DEBUG
            // Voor het maken van schermafbeeldingen vanaf de opdrachtregel:
            // SIMCTL_CHILD_DEBUG_SCREEN=instellingen xcrun simctl launch …
            .task {
                switch ProcessInfo.processInfo.environment["DEBUG_SCREEN"] {
                case "instellingen": showSettings = true
                case "toevoegen": editorMode = .add
                default: break
                }
            }
            #endif
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
        // .insetGrouped is de standaard: grijze achtergrond, witte container.
        .listStyle(.insetGrouped)
        .animation(.default, value: store.scheduled)
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

#Preview {
    ContentView().environmentObject(PlanStore())
}
