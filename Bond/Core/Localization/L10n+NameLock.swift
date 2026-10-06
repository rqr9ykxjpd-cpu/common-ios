import Foundation

extension L10n {
    /// Görünen ad kilidi (sunucu: 20261006050000_name_lock).
    enum NameLock {
        static var title: String { String(localized: "title", table: "NameLock") }
        static var lockedHint: String { String(localized: "lockedHint", table: "NameLock") }
        static var onceHint: String { String(localized: "onceHint", table: "NameLock") }
        static var lockedError: String { String(localized: "lockedError", table: "NameLock") }
    }
}
