import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = DishesViewModel()
    @State private var newDishName: String = ""
    @State private var editingDish: Dish? = nil
    @State private var showResetAlert: Bool = false
    @State private var showAddAlert: Bool = false
    @State private var showEditAlert: Bool = false
    @State private var isSharing: Bool = false
    @State private var sharedDishes: [Dish]? = nil
    @State private var showSettings: Bool = false

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.dishes.isEmpty {
                    VStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 40))
                            .foregroundColor(Color.gray)
                            .padding(.bottom, 20)
                        Text(LocalizedStringKey("empty_state_message"))
                            .font(.headline)
                            .foregroundColor(Color.gray)
                            .padding(.bottom, 60)
                    }
                } else {
                    List {
                        ForEach(viewModel.dishes.indices, id: \.self) { index in
                            let dish = viewModel.dishes[index]
                            DishRow(dish: dish, index: index, onEdit: {
                                startEditing(dish)
                            }, onDelete: {
                                deleteDish(at: IndexSet(integer: index))
                            })
                        }
                        .onMove(perform: { source, destination in
                            withAnimation {
                                viewModel.dishes.move(fromOffsets: source, toOffset: destination)
                            }
                            viewModel.notifyWidgetIfFirstDishChanged()
                        })
                    }
                }

                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        FloatingButtons(
                            onAdd: { showAddAlert = true },
                            showSettings: $showSettings
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { isSharing = true }) {
                            Label(LocalizedStringKey("share"), systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive, action: { showResetAlert = true }) {
                            Label(LocalizedStringKey("reset"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                }
            }
            .onAppear {
                viewModel.loadDishes()
                viewModel.loadCompletedDishes()
            }
            .onChange(of: viewModel.dishes) { _, _ in
                viewModel.saveDishes()
                viewModel.notifyWidgetIfFirstDishChanged()
            }
            .alert(LocalizedStringKey("add_alert_title"), isPresented: $showAddAlert) {
                TextField(LocalizedStringKey("add_alert_placeholder"), text: $newDishName)
                    .focused($isTextFieldFocused)
                Button(LocalizedStringKey("add"), action: {
                    addDish()
                    isTextFieldFocused = false
                })
                Button(LocalizedStringKey("cancel"), role: .cancel, action: {
                    isTextFieldFocused = false
                })
            }
            .alert(LocalizedStringKey("edit_alert_title"), isPresented: $showEditAlert) {
                TextField(LocalizedStringKey("edit_alert_placeholder"), text: $newDishName)
                    .focused($isTextFieldFocused)
                Button(LocalizedStringKey("save"), action: {
                    saveEditedDish()
                    isTextFieldFocused = false
                })
                Button(LocalizedStringKey("cancel"), role: .cancel, action: {
                    isTextFieldFocused = false
                })
            }
            // Alert voor het resetten van gerechten
            .alert(LocalizedStringKey("reset_alert_title"), isPresented: $showResetAlert) {
                Button(LocalizedStringKey("yes"), role: .destructive, action: resetDishes)
                Button(LocalizedStringKey("cancel"), role: .cancel) {}
            }
            // Deel gerechten via een ShareSheet
            .sheet(isPresented: $isSharing) {
                if let data = viewModel.exportDishesAsJSON() {
                    ShareSheet(activityItems: [data])
                }
            }
            // Instellingen openen
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    // Function to add dishes
    private func addDish() {
        guard !newDishName.isEmpty else { return }
        let emojis = detectEmojis(for: newDishName)
        viewModel.dishes.append(Dish(id: UUID(), name: newDishName, emoji: emojis))
    }
    // Functie om alle gerechten te resetten
    private func resetDishes() {
        viewModel.dishes.removeAll()
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Functie om een gerecht te bewerken
    private func startEditing(_ dish: Dish) {
        editingDish = dish
        newDishName = dish.name
        showEditAlert = true
    }

    // Functie om een bewerkt gerecht op te slaan
    private func saveEditedDish() {
        guard let dish = editingDish else { return }
        if let index = viewModel.dishes.firstIndex(where: { $0.id == dish.id }) {
            let updatedDish = Dish(id: dish.id, name: newDishName, emoji: detectEmojis(for: newDishName))
            viewModel.dishes[index] = updatedDish
        }
        newDishName = ""
        editingDish = nil
        showEditAlert = false
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Functie om gerechten te delen
    private func shareDishes() {
        isSharing = true
    }

    // Functie om een gerecht te verwijderen
    private func deleteDish(at offsets: IndexSet) {
        for index in offsets {
            let dish = viewModel.dishes[index]
            viewModel.addToCompleted(dish)
        }
        viewModel.dishes.remove(atOffsets: offsets)
        viewModel.saveCompletedDishes()
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Functie om emoji’s te detecteren voor een gerecht
    private func detectEmojis(for dishName: String) -> String {
        let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
            mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
        }
        let defaultEmoji = "🍽️"
        return matchedEmojis.isEmpty ? defaultEmoji : matchedEmojis.prefix(3).joined(separator: " ")
    }
}

// Preview van ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
