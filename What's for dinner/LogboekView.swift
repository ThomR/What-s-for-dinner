import SwiftUI
/// ✅ Toont een lijst van voltooide gerechten in omgekeerde chronologische volgorde.

struct LogboekView: View {
    let viewModel: DishesViewModel

    var body: some View {
        VStack {
            if viewModel.completedDishes.isEmpty {
                Text(LocalizedStringKey("no_completed_dishes_message"))
                    .foregroundColor(.gray)
                    .padding()
            } else {
                completedListView
            }
        }
        .navigationTitle(LocalizedStringKey("completed_dishes_title"))
        .onAppear {
            viewModel.loadCompletedDishes()
        }
    }
    
    private var completedListView: some View {
        let sortedDishes = viewModel.completedDishes.sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }
        return List(sortedDishes) { dish in
            HStack {
                Text(dish.name)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .lineLimit(1)
                Spacer()
                Text(dish.emoji)
                    .font(.largeTitle)
                    .fontDesign(.rounded)
            }
            .accessibilityLabel(dish.name)
        }
    }
}
