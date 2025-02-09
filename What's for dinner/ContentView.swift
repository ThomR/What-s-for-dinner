import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

struct ContentView: View {
    // MARK: - Properties
    @EnvironmentObject var viewModel: DishesViewModel  // ✅ Correcte binding
    @State private var newDishName: String = ""
    @State private var editingDish: Dish? = nil
    @State private var showResetAlert: Bool = false
    @State private var showAddAlert: Bool = false
    @State private var showEditAlert: Bool = false
    @State private var isSharing: Bool = false
    @State private var sharedDishes: [Dish]? = nil
    @State private var showSettings: Bool = false

    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.dishes.isEmpty {
                    emptyStateView
                } else {
                    dishesListView
                }
                VStack {
                    Spacer()
                    FloatingButtons(onAdd: { showAddAlert = true }, showSettings: $showSettings)
                        .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
            .toolbar { toolbarContent }
            .onAppear {
                viewModel.loadDishes()
                viewModel.loadCompletedDishes()
            }
            .onChange(of: viewModel.dishes) { _, _ in
               viewModel.saveDishes()
               viewModel.notifyWidgetIfFirstDishChanged()
           }
            .alert(LocalizedStringKey("add_alert_title"), isPresented: $showAddAlert) {
                addAlertContent
            }
            .alert(LocalizedStringKey("edit_alert_title"), isPresented: $showEditAlert) {
                editAlertContent
            }
            .alert(LocalizedStringKey("reset_alert_title"), isPresented: $showResetAlert) {
                resetAlertContent
            }
            .sheet(isPresented: $isSharing) {
                if let fileURL = viewModel.exportDishesFileURL() {
                    ShareSheet(activityItems: [fileURL])
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
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
    }
    
    private var dishesListView: some View {
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
    
    private var toolbarContent: some ToolbarContent {
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
    
    private var addAlertContent: some View {
        Group {
            TextField(LocalizedStringKey("add_alert_placeholder"), text: $newDishName)
                .focused($isTextFieldFocused)
            Button(LocalizedStringKey("add"), action: {
                addDish()
                dismissKeyboard()
            })
            Button(LocalizedStringKey("cancel"), role: .cancel, action: {
                dismissKeyboard()
            })
        }
    }
    
    private var editAlertContent: some View {
        Group {
            TextField(LocalizedStringKey("edit_alert_placeholder"), text: $newDishName)
                .focused($isTextFieldFocused)
            Button(LocalizedStringKey("save"), action: {
                saveEditedDish()
                dismissKeyboard()
            })
            Button(LocalizedStringKey("cancel"), role: .cancel, action: {
                dismissKeyboard()
            })
        }
    }
    
    private var resetAlertContent: some View {
        Group {
            Button(LocalizedStringKey("yes"), role: .destructive, action: resetDishes)
            Button(LocalizedStringKey("cancel"), role: .cancel) {}
        }
    }
    
    // MARK: - Functions
    
    /// Sluit het toetsenbord af
    private func dismissKeyboard() {
        isTextFieldFocused = false
    }
    
    /// Voeg een nieuw gerecht toe
    private func addDish() {
        guard !newDishName.isEmpty else { return }
        withAnimation {
            let emojis = detectEmojis(for: newDishName)
            viewModel.dishes.append(Dish(id: UUID(), name: newDishName, emoji: emojis))
            // Reset het inputveld na toevoegen
            newDishName = ""
        }
    }
    
    /// Reset alle gerechten
    private func resetDishes() {
        withAnimation {
            viewModel.dishes.removeAll()
            viewModel.notifyWidgetIfFirstDishChanged()
        }
    }
    
    /// Start met het bewerken van een gerecht
    private func startEditing(_ dish: Dish) {
        editingDish = dish
        newDishName = dish.name
        showEditAlert = true
    }
    
    /// Sla een bewerkt gerecht op
    private func saveEditedDish() {
        guard let dish = editingDish else { return }
        if let index = viewModel.dishes.firstIndex(where: { $0.id == dish.id }) {
            let updatedDish = Dish(id: dish.id, name: newDishName, emoji: detectEmojis(for: newDishName))
            withAnimation {
                viewModel.dishes[index] = updatedDish
            }
        }
        newDishName = ""
        editingDish = nil
        showEditAlert = false
        viewModel.notifyWidgetIfFirstDishChanged()
    }
    
    /// Verwijder een gerecht en voeg het toe aan de 'voltooide' lijst
    private func deleteDish(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let dish = viewModel.dishes[index]
                viewModel.addToCompleted(dish)
            }
            viewModel.dishes.remove(atOffsets: offsets)
            viewModel.saveCompletedDishes()
            viewModel.notifyWidgetIfFirstDishChanged()
        }
    }
    
    /// Detecteer emoji’s op basis van de naam van het gerecht
    private func detectEmojis(for dishName: String) -> String {
        let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
            mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
        }
        let defaultEmoji = "🍽️"
        return matchedEmojis.isEmpty ? defaultEmoji : matchedEmojis.prefix(3).joined(separator: " ")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
