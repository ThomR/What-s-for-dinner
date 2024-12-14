import SwiftUI
import Foundation

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}
