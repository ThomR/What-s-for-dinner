/// ✅ Bevat `DateTracker` om de huidige dag bij te houden en `DishRow` view om een gerecht in de lijst weer te geven.
import SwiftUI
import Combine

class DateTracker: ObservableObject {
    @Published var currentDayIndex: Int = DateTracker.calculateTodayIndex()
    private var timer: AnyCancellable?
    
    init() {
        startDailyUpdate()
    }
    
    private func startDailyUpdate() {
        let now = Date()
        let nextMidnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        timer = Timer.publish(every: timeInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.currentDayIndex = DateTracker.calculateTodayIndex()
                print("Current day index updated to: \(self?.currentDayIndex ?? 0)")
            }
    }
    
    static func calculateTodayIndex() -> Int {
        return (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }
}

struct DishRow: View {
    let dish: Dish
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @AppStorage("daysInsteadOfNumbers") private var daysInsteadOfNumbers: Bool = false
    @EnvironmentObject var dateTracker: DateTracker

    static let daysOfWeek: [LocalizedStringKey] = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color("InfoColor-500"))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(circleLabel)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
            Text(dish.name)
                .font(.headline)
                .fontWeight(.bold)
                .padding(8)
                .lineLimit(3)
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

    private var circleLabel: LocalizedStringKey {
        if daysInsteadOfNumbers {
            let dayIndex = (dateTracker.currentDayIndex + index) % 7
            return Self.daysOfWeek[dayIndex]
        } else {
            return LocalizedStringKey("\(index + 1)")
        }
    }
}
