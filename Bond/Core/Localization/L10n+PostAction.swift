import Foundation

extension L10n {
    /// Gönderideki düğme (kurucu ve Common hesabı ekler).
    enum PostAction {
        static var invite: String { String(localized: "invite", table: "PostAction") }
        static var appIcon: String { String(localized: "appIcon", table: "PostAction") }
        static var plus: String { String(localized: "plus", table: "PostAction") }
        static var add: String { String(localized: "add", table: "PostAction") }
        static var remove: String { String(localized: "remove", table: "PostAction") }
    }
}
