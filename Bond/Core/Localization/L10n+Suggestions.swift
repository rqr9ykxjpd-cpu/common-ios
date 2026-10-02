import Foundation

extension L10n {
    /// Sohbet sekmesindeki "Tanıyor olabileceğin kişiler".
    enum Suggestions {
        static var title: String { String(localized: "title", table: "Suggestions") }
        static var classmate: String { String(localized: "classmate", table: "Suggestions") }
        static var connection: String { String(localized: "connection", table: "Suggestions") }
        static var dismiss: String { String(localized: "dismiss", table: "Suggestions") }
        static var dismissFailed: String { String(localized: "dismissFailed", table: "Suggestions") }
        static var openHint: String { String(localized: "openHint", table: "Suggestions") }
        static func mutual(_ count: Int) -> String {
            String(format: String(localized: "mutual", table: "Suggestions"), locale: L10n.appLocale, Int64(count))
        }
        static func interests(_ count: Int) -> String {
            String(format: String(localized: "interests", table: "Suggestions"), locale: L10n.appLocale, Int64(count))
        }
    }
}
