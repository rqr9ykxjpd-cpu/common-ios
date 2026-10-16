import Foundation

extension L10n {
    /// Dondurulan hesabın gördüğü ekran (1.1.5).
    enum FrozenAccount {
        static var title: String { String(localized: "title", table: "FrozenAccount") }
        static var body: String { String(localized: "body", table: "FrozenAccount") }
        static var appeal: String { String(localized: "appeal", table: "FrozenAccount") }
        static var contact: String { String(localized: "contact", table: "FrozenAccount") }
    }
}
