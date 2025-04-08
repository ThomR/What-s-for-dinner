import SwiftUI
import WidgetKit
import UniformTypeIdentifiers

/// ✅ Hoofdscherm van de app waar de gebruiker gerechten kan toevoegen, bewerken, verwijderen, delen en sorteren.
struct ContentView: View {
    @EnvironmentObject var viewModel: DishesViewModel
    @State private var newDishName: String = ""
    @State private var editingDish: Dish? = nil
    @State private var showResetAlert: Bool = false
    @State private var showAddAlert: Bool = false
    @State private var showEditAlert: Bool = false
    @State private var isSharing: Bool = false
    @State private var showSettings: Bool = false

    @FocusState private var isTextFieldFocused: Bool

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
            .task {
                viewModel.loadDishes()
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
            alertTextField()
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
            alertTextField()
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
        
    private func alertTextField() -> some View {
        TextField(LocalizedStringKey("add_alert_placeholder"), text: $newDishName)
            .focused($isTextFieldFocused)
    }
    
    private func dismissKeyboard() {
        isTextFieldFocused = false
    }
    
    private func addDish() {
        guard !newDishName.isEmpty else { return }
        withAnimation {
            let emojis = detectEmojis(for: newDishName)
            viewModel.dishes.append(Dish(id: UUID(), name: newDishName, emoji: emojis))
            newDishName = ""
        }
    }
    
    private func resetDishes() {
        withAnimation {
            viewModel.dishes.removeAll()
            viewModel.notifyWidgetIfFirstDishChanged()
        }
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
            withAnimation {
                viewModel.dishes[index] = updatedDish
            }
        }
        newDishName = ""
        editingDish = nil
        showEditAlert = false
        viewModel.notifyWidgetIfFirstDishChanged()
    }
    
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
    
    private func detectEmojis(for dishName: String) -> String {
        let matchedEmojis = EmojiMapping.mappings.compactMap { mapping -> String? in
            mapping.value.contains(where: dishName.lowercased().contains) ? mapping.key : nil
        }
        let result = matchedEmojis.prefix(3).joined(separator: " ")
        return result.isEmpty ? "🍽️" : result
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension String {
    static func ifEmpty(_ string: String, default: String) -> String {
        string.isEmpty ? `default` : string
    }
}
