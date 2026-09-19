import SwiftUI

/// De zwevende balk onderaan: toevoegen links, instellingen rechts.
///
/// De navigatiebalk is daarmee helemaal leeg, zodat de titel bovenaan kan staan
/// in plaats van onder een rij knoppen.
struct FloatingActionBar: View {
    /// `nil` als je niets mag toevoegen; dan verdwijnt de knop.
    let onAdd: (() -> Void)?
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let onAdd {
            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("floating_button"))
                        .fontWeight(.semibold)
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                }
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
            }
            .modifier(FloatingButtonAppearance(shape: .capsule))
            }

            Spacer(minLength: 8)

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .modifier(FloatingButtonAppearance(shape: .circle))
            .accessibilityLabel(LocalizedStringKey("settings_title"))
        }
        .padding(.horizontal)
    }
}

/// Op iOS 26 het echte Liquid Glass van het systeem: dat reageert op wat eronder
/// langsschuift en licht op bij het indrukken. Daaronder valt het terug op een
/// materiaal-capsule, want die effecten bestaan daar simpelweg niet.
private struct FloatingButtonAppearance: ViewModifier {
    enum Shape {
        case capsule
        case circle
    }

    let shape: Shape

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(shape == .circle ? .circle : .capsule)
                .controlSize(.large)
        } else {
            switch shape {
            case .capsule:
                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: Capsule())
            case .circle:
                content
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
        FloatingActionBar(onAdd: {}, onSettings: {})
    }
}
