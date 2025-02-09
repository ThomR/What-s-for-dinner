import SwiftUI

// Logbook view that ties into Setting for viewing a history of all added dishes
struct LogboekView: View {
    @EnvironmentObject var viewModel: DishesViewModel

    var body: some View {
        VStack {
            if viewModel.completedDishes.isEmpty {
                Text(LocalizedStringKey("no_completed_dishes_message"))
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(viewModel.completedDishes.sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }) { dish in
                    HStack {
                        Text(dish.name)
                            .font(.headline)
                        Spacer()
                        Text(dish.emoji)
                            .font(.largeTitle)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("completed_dishes_title"))
        .onAppear {
            viewModel.loadCompletedDishes()
        }
    }
}
