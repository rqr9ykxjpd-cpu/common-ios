import Foundation

extension L10n {
    /// Ayarlar → Hesabın: kullanıcı adını değiştirme.
    enum AccountSettings {
        static var changeTitle: String { String(localized: "changeTitle", table: "AccountSettings") }
        static var changeBody: String { String(localized: "changeBody", table: "AccountSettings") }
        static var rowHint: String { String(localized: "rowHint", table: "AccountSettings") }
    }
}
