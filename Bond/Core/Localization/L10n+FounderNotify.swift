import Foundation

extension L10n {
    /// Kurucu: tek kişiye bildirim.
    enum FounderNotify {
        static var action: String { String(localized: "action", table: "FounderNotify") }
        static var title: String { String(localized: "title", table: "FounderNotify") }
        static var titlePlaceholder: String { String(localized: "titlePlaceholder", table: "FounderNotify") }
        static var bodyPlaceholder: String { String(localized: "bodyPlaceholder", table: "FounderNotify") }
        static var send: String { String(localized: "send", table: "FounderNotify") }
        static var sent: String { String(localized: "sent", table: "FounderNotify") }
        static var failed: String { String(localized: "failed", table: "FounderNotify") }
        static func hint(_ name: String) -> String {
            String(format: String(localized: "hint", table: "FounderNotify"), name)
        }
    }
}
