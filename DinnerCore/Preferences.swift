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
        static let usesSharedList = "usesSharedList"
        static let sharedZoneName = "sharedZoneName"
        static let sharedZoneOwner = "sharedZoneOwner"
        static let sharedListReadOnly = "sharedListReadOnly"
        static let sharedListOwnerName = "sharedListOwnerName"
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

    /// Of de app de lijst van iemand anders toont in plaats van de eigen.
    ///
    /// Dit moet een start overleven. Anders denkt de app bij elke opstart dat je
    /// je eigen lijst bewerkt, tot er toevallig iets uit de gedeelde database
    /// binnenkomt — en gaan wijzigingen in dat gaatje naar de verkeerde zone.
    static var usesSharedList: Bool {
        get { defaults.bool(forKey: Key.usesSharedList) }
        set { defaults.set(newValue, forKey: Key.usesSharedList) }
    }

    /// Welke gedeelde zone het is, als naam en eigenaar. Zonder dit weet de app
    /// na een herstart wel dát hij de lijst van een ander toont, maar niet
    /// wélke — en dan gaan wijzigingen nergens heen.
    static var sharedZone: (name: String, owner: String)? {
        get {
            guard let name = defaults.string(forKey: Key.sharedZoneName),
                  let owner = defaults.string(forKey: Key.sharedZoneOwner) else { return nil }
            return (name, owner)
        }
        set {
            defaults.set(newValue?.name, forKey: Key.sharedZoneName)
            defaults.set(newValue?.owner, forKey: Key.sharedZoneOwner)
        }
    }

    /// Of je in de gedeelde lijst alleen mag kijken. De eigenaar bepaalt dit.
    static var sharedListReadOnly: Bool {
        get { defaults.bool(forKey: Key.sharedListReadOnly) }
        set { defaults.set(newValue, forKey: Key.sharedListReadOnly) }
    }

    /// De naam van de eigenaar van de lijst waaraan je meedoet, om te tonen.
    static var sharedListOwnerName: String? {
        get { defaults.string(forKey: Key.sharedListOwnerName) }
        set { defaults.set(newValue, forKey: Key.sharedListOwnerName) }
    }

    /// Of de lijst die je ziet van een ander is en je er niets aan mag veranderen.
    static var isReadOnlyList: Bool {
        usesSharedList && sharedListReadOnly
    }

    /// Alles vergeten over een gedeelde lijst: terug naar je eigen.
    static func forgetSharedList() {
        usesSharedList = false
        sharedZone = nil
        sharedListReadOnly = false
        sharedListOwnerName = nil
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
