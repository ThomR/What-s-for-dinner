import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = DishesViewModel()
    @State private var newDishName: String = ""
    @State private var showResetAlert: Bool = false
    @State private var showAddAlert: Bool = false
    @State private var showSettings: Bool = false
    @State private var lockedItems: Set<UUID> = []
    @FocusState private var isTextFieldFocused: Bool // Focus state toegevoegd

    // Body of the app -- shows all the content
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
                    VStack {
                        List {
                            ForEach(viewModel.dishes.indices, id: \ .self) { index in
                                let dish = viewModel.dishes[index]
                                DishRow(dish: dish, index: index, isLocked: lockedItems.contains(dish.id)) {
                                    toggleLock(dish)
                                } onDelete: {
                                    deleteDish(at: IndexSet(integer: index))
                                }
                                .moveDisabled(lockedItems.contains(dish.id))
                            }
                            .onMove(perform: { source, destination in
                                withAnimation {
                                    viewModel.dishes.move(fromOffsets: source, toOffset: destination)
                                }
                                viewModel.notifyWidgetIfFirstDishChanged()
                            })
                        }
                    }
                }

                VStack {
                    Spacer()
                    FloatingButtons(
                        onAdd: { showAddAlert = true },
                        showResetAlert: $showResetAlert,
                        showSettings: $showSettings
                    )
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
            .onAppear(perform: viewModel.loadDishes)
            .onChange(of: viewModel.dishes) { oldValue, newValue in
                viewModel.saveDishes()
                viewModel.notifyWidgetIfFirstDishChanged()
            }
            .alert(LocalizedStringKey("add_alert_title"), isPresented: $showAddAlert) {
                TextField(LocalizedStringKey("add_alert_placeholder"), text: $newDishName)
                    .focused($isTextFieldFocused) // Focus state gekoppeld aan het tekstveld
                Button(LocalizedStringKey("add"), action: {
                    addDish()
                    isTextFieldFocused = false // Focus verwijderen
                })
                Button(LocalizedStringKey("cancel"), role: .cancel, action: {
                    isTextFieldFocused = false // Focus verwijderen
                })
            }
            .alert(LocalizedStringKey("reset_alert_title"), isPresented: $showResetAlert) {
                Button(LocalizedStringKey("yes"), role: .destructive, action: resetDishes)
                Button(LocalizedStringKey("cancel"), role: .cancel) {}
            }
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
        newDishName = ""
    }

    // Function to delete dishes
    private func deleteDish(at offsets: IndexSet) {
        viewModel.dishes.remove(atOffsets: offsets)
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Function to reset/delete all dishes
    private func resetDishes() {
        viewModel.dishes.removeAll()
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Function to lock dishes on a day/priority
    private func toggleLock(_ dish: Dish) {
        if lockedItems.contains(dish.id) {
            lockedItems.remove(dish.id)
        } else {
            lockedItems.insert(dish.id)
        }
    }

    // Function to detect which emoji fits (from Structs.swift)
    private func detectEmojis(for dishName: String) -> String {
        let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
            mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
        }
        let defaultEmoji = "🍽️"
        return matchedEmojis.isEmpty ? defaultEmoji : matchedEmojis.prefix(3).joined(separator: " ")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
