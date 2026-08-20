import os

/// Eén plek voor de logcategorieën, zodat de Console te filteren is op subsysteem.
enum Log {
    private static let subsystem = "nl.whatsfordinner.app"

    static let store = Logger(subsystem: subsystem, category: "store")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let emoji = Logger(subsystem: subsystem, category: "emoji")
    static let watch = Logger(subsystem: subsystem, category: "watch")
}
