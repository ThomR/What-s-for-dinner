import SwiftUI

// Logbook view that ties into Setting for viewing a history of all added dishes
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
