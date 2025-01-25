import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = DishesViewModel()
    @State private var newDishName: String = ""
    @State private var editingDish: Dish? = nil
    @State private var showResetAlert: Bool = false
    @State private var showAddAlert: Bool = false
    @State private var showEditAlert: Bool = false
    @State private var showSettings: Bool = false
    @FocusState private var isTextFieldFocused: Bool

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

    // Function to delete dishes and save to completed dishes
    private func deleteDish(at offsets: IndexSet) {
        for index in offsets {
            let dish = viewModel.dishes[index]
            viewModel.addToCompleted(dish)
        }
        viewModel.dishes.remove(atOffsets: offsets)
        viewModel.saveCompletedDishes()
        viewModel.notifyWidgetIfFirstDishChanged()
    }
    
    // Function to reset/delete all dishes
    private func resetDishes() {
        viewModel.dishes.removeAll()
        viewModel.notifyWidgetIfFirstDishChanged()
    }

    // Function to detect which emoji fits (from Structs.swift)
    private func detectEmojis(for dishName: String) -> String {
        let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
            mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
        }
        let defaultEmoji = "🍽️"
        return matchedEmojis.isEmpty ? defaultEmoji : matchedEmojis.prefix(3).joined(separator: " ")
    }
    
    private func startEditing(_ dish: Dish) {
            editingDish = dish
            newDishName = dish.name
            showEditAlert = true
        }

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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
