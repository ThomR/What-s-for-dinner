import SwiftUI

/// Toevoegen en hernoemen van een gerecht.
///
/// Bewust een sheet en geen `TextField` in een `.alert`: zo'n tekstveld neemt de
/// waarde over die de state hád op het moment van tonen, waardoor je bij het
/// bewerken van het volgende gerecht de vorige naam te zien kreeg.
struct DishEditorView: View {
    enum Mode {
        case add
        case edit(Dish)
    }

    let mode: Mode
    let onSubmit: (String) -> Void

    @State private var name: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, onSubmit: @escaping (String) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        // De naam hoort bij deze sheet en wordt bij het openen ingesteld, niet
        // gedeeld met het scherm eronder.
        switch mode {
        case .add: _name = State(initialValue: "")
        case .edit(let dish): _name = State(initialValue: dish.name)
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewEmoji: String {
        EmojiSuggester.suggest(for: trimmed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(LocalizedStringKey("add_alert_placeholder"), text: $name)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .fontDesign(.rounded)
                        // Meteen zichtbaar welke emoji het gerecht krijgt.
                        Text(trimmed.isEmpty ? " " : previewEmoji)
                            .font(.title2)
                            .animation(.default, value: previewEmoji)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Een kruisje in plaats van "Annuleer": dat laat ruimte voor
                    // de titel, die anders niet fatsoenlijk paste.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(LocalizedStringKey("cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle, action: save)
                        .disabled(trimmed.isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.height(180)])
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .add: return "add_alert_title"
        case .edit: return "edit_alert_title"
        }
    }

    private var saveTitle: LocalizedStringKey {
        switch mode {
        case .add: return "add"
        case .edit: return "save"
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        dismiss()
    }
}
