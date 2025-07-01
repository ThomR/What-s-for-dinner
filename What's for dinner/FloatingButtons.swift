/// ✅ Bevat de drijvende knoppen voor het toevoegen van een gerecht en openen van instellingen.

import SwiftUI

// Pas de buttonStyle extension aan
private extension View {
    func buttonStyle() -> some View {
        self
            .padding(12)
            .padding(.leading, 8)
            .background(
                // Gebruik .ultraThinMaterial voor een subtiel glaseffect
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 30)
            )
    }
}

// Pas de body van FloatingButtons aan
struct FloatingButtons: View {
    let onAdd: () -> Void
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onAdd) {
                HStack {
                    Text(LocalizedStringKey("floating_button"))
                        .fontWeight(.bold)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                }
            }
            .buttonStyle()
            // Gebruik een voorgrondstijl om de tekstkleur aan te passen aan de lichte/donkere modus
            .foregroundStyle(.primary)

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .padding(12)
                    .font(.system(size: 24))
                    .background(
                        // Gebruik hier ook .ultraThinMaterial
                        .regularMaterial,
                        in: Circle()
                    )
            }
            .foregroundStyle(.primary)
        }
        .padding()
        .fontDesign(.rounded)
    }
}
