import SwiftUI

struct LogboekView: View {
    var body: some View {
        VStack {
            Text("history_title")
                .font(.largeTitle)
                .padding()
            Text("Hier komt het logboek met alle activiteiten.")
                .padding()
        }
        .navigationTitle("history_title")
    }
}
