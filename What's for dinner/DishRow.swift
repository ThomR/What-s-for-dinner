import SwiftUI
import Foundation

struct DishRow: View {
    let dish: Dish
    let index: Int
    let isLocked: Bool
    let onToggleLock: () -> Void
    let onDelete: () -> Void

    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]

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
        .opacity(isLocked ? 0.6 : 1.0)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onToggleLock) {
                Label(isLocked ? "Unlock" : "Lock", systemImage: isLocked ? "lock.open" : "lock")
                    .font(.system(size: 20, weight: .bold))
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "checkmark")
                    .font(Font.title.weight(.bold))
            }
            .tint(.green)
        }
    }

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
