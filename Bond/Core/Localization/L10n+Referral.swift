import Foundation

extension L10n {
    /// Davet: kayıttaki "Seni kim davet etti?" ve ayarlardaki "Arkadaşını davet et".
    enum Referral {
        static var fieldTitle: String { String(localized: "fieldTitle", table: "Referral") }
        static var fieldPlaceholder: String { String(localized: "fieldPlaceholder", table: "Referral") }
        static var fieldHint: String { String(localized: "fieldHint", table: "Referral") }
        static var found: String { String(localized: "found", table: "Referral") }
        static var notFound: String { String(localized: "notFound", table: "Referral") }
        static func notSaved(_ username: String) -> String {
            String(format: String(localized: "notSaved", table: "Referral"), username)
        }
        static var rowTitle: String { String(localized: "rowTitle", table: "Referral") }
        static var rowHint: String { String(localized: "rowHint", table: "Referral") }
        static var headline: String { String(localized: "headline", table: "Referral") }
        static var body: String { String(localized: "body", table: "Referral") }
        static var proNote: String { String(localized: "proNote", table: "Referral") }
        static var yourUsername: String { String(localized: "yourUsername", table: "Referral") }
        static var copy: String { String(localized: "copy", table: "Referral") }
        static var copied: String { String(localized: "copied", table: "Referral") }
        static var joined: String { String(localized: "joined", table: "Referral") }
        static var verified: String { String(localized: "verified", table: "Referral") }
        static var share: String { String(localized: "share", table: "Referral") }
        static func shareMessage(username: String, link: String) -> String {
            String(format: String(localized: "shareMessage", table: "Referral"), username, link)
        }
    }
}
