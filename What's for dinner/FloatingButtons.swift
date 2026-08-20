import SwiftUI

/// De zwevende knop om een gerecht toe te voegen.
struct FloatingButtons: View {
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey("floating_button"))
                    .fontWeight(.semibold)
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
            }
            .fontDesign(.rounded)
            // Neutrale tekst, zodat het glas het werk doet en niet de kleur.
            .foregroundStyle(.primary)
        }
        .modifier(FloatingButtonAppearance())
    }
}

/// Op iOS 26 het echte Liquid Glass van het systeem: dat reageert op wat eronder
/// langsschuift en licht op bij het indrukken. Daaronder valt het terug op een
/// materiaal-capsule, want die effecten bestaan daar simpelweg niet.
private struct FloatingButtonAppearance: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                // .glass en niet .glassProminent: doorschijnend, met wat
                // eronder ligt er doorheen. De gevulde variant is bedoeld voor
                // een knop die alles moet overstemmen.
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        } else {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: Capsule())
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
        FloatingButtons(onAdd: {})
    }
}
