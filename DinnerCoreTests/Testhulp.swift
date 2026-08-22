import Foundation

/// Een vaste kalender: Nederlandse tijdzone, maandag als eerste dag. Tests mogen
/// niet van de instellingen van de machine afhangen waarop ze draaien.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
    calendar.locale = Locale(identifier: "nl_NL")
    calendar.firstWeekday = 2
    return calendar
}()

/// Een moment op de dag, standaard 's ochtends — nooit `Date()`, want een test
/// die van vandaag afhangt geeft morgen een ander antwoord.
func datum(_ jaar: Int, _ maand: Int, _ dag: Int, uur: Int = 9) -> Date {
    var components = DateComponents()
    components.year = jaar
    components.month = maand
    components.day = dag
    components.hour = uur
    return testCalendar.date(from: components)!
}

func gerecht(_ naam: String, emoji: String = "🍽️") -> Dish {
    Dish(name: naam, emoji: emoji, addedAt: datum(2026, 1, 1))
}

/// Een planning die op `start` begint met de opgegeven gerechten.
func planning(vanaf start: Date, _ namen: String...) -> MealPlan {
    MealPlan(
        dishes: namen.map { gerecht($0) },
        anchorDate: testCalendar.startOfDay(for: start),
        log: []
    )
}

/// Een lege map om een `DishStore` in te laten schrijven, in plaats van de
/// echte App Group-container.
func tijdelijkeMap() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("dinnertest-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Een gerecht zoals versie 1 het in `UserDefaults` bewaarde.
func versie1Gerecht(_ naam: String, emoji: String = "🍕", voltooidOp: Date? = nil) -> [String: Any] {
    var dict: [String: Any] = ["id": UUID().uuidString, "name": naam, "emoji": emoji]
    if let voltooidOp {
        // Versie 1 gebruikte de standaard-JSONEncoder, en die schrijft datums
        // als seconden sinds 2001.
        dict["completedDate"] = voltooidOp.timeIntervalSinceReferenceDate
    }
    return dict
}
