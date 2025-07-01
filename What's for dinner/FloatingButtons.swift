/// ✅ Bevat de drijvende knoppen voor het toevoegen van een gerecht en openen van instellingen.

import SwiftUI

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

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .padding(12)
                    .font(.system(size: 24))
                    .background(
                        Circle()
                            .fill(Color("GrayColor-500"))
                            .shadow(color: Color("GrayColor-700"), radius: 0, x: 0, y: 4)
                    )
            }
        }
        .padding()
        .foregroundColor(.white)
        .fontDesign(.rounded)
    }
}

private extension View {
    func buttonStyle() -> some View {
        self
            .padding(12)
            .padding(.leading, 8)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color("SuccessColor-500"))
                    .shadow(color: Color("SuccessColor-700"), radius: 0, x: 0, y: 4)
            )
    }
}
