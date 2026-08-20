import Foundation

/// De instellingen die niet alleen de app aangaan.
///
/// Ze staan in de App Group en niet in `UserDefaults.standard`, omdat de widget
/// en de complicatie zelf moeten kunnen bepalen of de lijst mag doorschuiven.
/// Stonden ze in de standaard-defaults, dan zou een extensie ze niet zien.
enum Preferences {

    enum Key {
        static let showsDayLabels = "daysInsteadOfNumbers"
        static let autoAdvance = "autoCompleteDish"
        static let didMigrate = "didMigratePreferences"
    }

    static let defaults: UserDefaults = {
        #if os(watchOS)
        let group = DishStore.Group.watch
        #else
        let group = DishStore.Group.phone
        #endif
        return UserDefaults(suiteName: group) ?? .standard
    }()

    /// Dagen in plaats van nummers naast de gerechten.
    static var showsDayLabels: Bool {
        get { defaults.bool(forKey: Key.showsDayLabels) }
        set { defaults.set(newValue, forKey: Key.showsDayLabels) }
    }

    /// Of het bovenste gerecht elke dag vanzelf afgestreept wordt.
    ///
    /// Alleen zinnig met daglabels: zonder dagen betekent "morgen" niets en
    /// streept de gebruiker zelf af.
    static var autoAdvance: Bool {
        get { defaults.bool(forKey: Key.autoAdvance) && showsDayLabels }
        set { defaults.set(newValue, forKey: Key.autoAdvance) }
    }

    /// De ruwe stand van de schakelaar, los van de koppeling met daglabels.
    static var autoAdvanceSetting: Bool {
        defaults.bool(forKey: Key.autoAdvance)
    }

    /// Haalt instellingen van vóór versie 2 uit de standaard-defaults op.
    static func migrateIfNeeded() {
        guard !defaults.bool(forKey: Key.didMigrate) else { return }
        let standard = UserDefaults.standard
        for key in [Key.showsDayLabels, Key.autoAdvance] where standard.object(forKey: key) != nil {
            defaults.set(standard.bool(forKey: key), forKey: key)
        }
        defaults.set(true, forKey: Key.didMigrate)
    }
}
