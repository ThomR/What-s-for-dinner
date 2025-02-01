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
                .padding(12)
                .padding(.leading, 8)
                .fontDesign(.rounded)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color("SuccessColor-500"))
                        .shadow(color: Color("SuccessColor-700"), radius: 0, x: 0, y: 4)
                )
                .foregroundColor(.white)
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(Color.white)
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
    }
}
