import SwiftUI
import Foundation

// Variables in Dishrow
struct DishRow: View {
    let dish: Dish
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]

    // View for each Dish row
    var body: some View {
        HStack {
            Circle()
                .fill(Color("InfoColor"))
                .fontDesign(.rounded)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(circleContent)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
            Text(dish.name)
                .font(.headline)
                .fontWeight(.bold)
                .padding()
                .fontDesign(.rounded)
            Spacer()
            Text(dish.emoji)
                .font(.largeTitle)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onEdit) {
                Label(LocalizedStringKey("edit"), systemImage: "pencil")
                    .font(Font.title.weight(.bold))
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label(LocalizedStringKey("clear"), systemImage: "trash")
                    .font(Font.title.weight(.bold))
            }
            .tint(.red)
        }
    }

    // The blue circle for days/priority number
    private var circleContent: LocalizedStringKey {
        if daysInsteadOfNumbers {
            let todayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
            let dayIndex = (todayIndex + index) % 7
            return daysOfWeek[dayIndex]
        } else {
            return LocalizedStringKey("\(index + 1)")
        }
    }
}
