import SwiftUI
import Foundation

struct DishRow: View {
    let dish: Dish
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false

    private let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]
    
    // Een statische property die de berekende huidige dag cachet (bij opstart)
    private static let cachedTodayIndex: Int = {
        // De kalender geeft 1 voor zondag, 2 voor maandag, enz.
        // Door +5 en modulo 7 te doen, transformeer je dit naar een index waarbij maandag 0 wordt.
        return (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }()

    var body: some View {
        HStack {
            Circle()
                .fill(Color("InfoColor-500"))
                .fontDesign(.rounded)
                .frame(width: 30, height: 30)
                .overlay(
                    Text(circleContent)
                        .font(.subheadline)
                        .fontDesign(.rounded)
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
                Label(LocalizedStringKey("clear"), systemImage: "checkmark")
                    .font(Font.title.weight(.bold))
            }
            .tint(.green)
        }
    }

    // Gebruik de gecachte waarde in plaats van telkens Calendar.current te raadplegen.
    private var circleContent: LocalizedStringKey {
        if daysInsteadOfNumbers {
            let dayIndex = (DishRow.cachedTodayIndex + index) % 7
            return daysOfWeek[dayIndex]
        } else {
            return LocalizedStringKey("\(index + 1)")
        }
    }
}
