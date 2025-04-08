import SwiftUI

/// ✅ Hoofdweergave voor de Watch-app: toont een lijst van gerechten met optionele daglabels of nummers.
struct WatchAppView: View {
    @StateObject private var viewModel = WatchViewModel()
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private static let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.dishes.isEmpty {
                    Text(LocalizedStringKey("empty_state_message"))
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.dishes.indices, id: \.self) { index in
                            let dish = viewModel.dishes[index]
                            HStack {
                                Text(circleContent(for: index))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.accentColor))
                                    .frame(minWidth: 24)
                                    .padding(.trailing, 2)
                                Text(dish.name)
                                    .font(.headline)
                                    .fontDesign(.rounded)
                                    .lineLimit(2)
                                Spacer()
                                Text(dish.emoji)
                                    .font(.title3)
                                    .fontDesign(.rounded)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("title"))
        }
    }

    private func circleContent(for index: Int) -> LocalizedStringKey {
        if daysInsteadOfNumbers {
            let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            let dayIndex = (todayIndex + index) % 7
            return Self.daysOfWeek[dayIndex]
        } else {
            return LocalizedStringKey("\(index + 1)")
        }
    }
}

#Preview {
    WatchAppView()
}
