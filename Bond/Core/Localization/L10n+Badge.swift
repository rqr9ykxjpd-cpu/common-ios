import Foundation

extension L10n {
    enum Badge {
        static var moderator: String { String(localized: "badge.moderator") }
        static var founder: String { String(localized: "badge.founder") }
        static var founderSubtitle: String { String(localized: "badge.founderSubtitle") }
        /// Künye üst satırı: Girişimci · Startup Developer
        static var founderCredRoles: String { String(localized: "badge.founderCredRoles") }
        /// Künye alt satırı: Concept Manager
        static var founderCredFocus: String { String(localized: "badge.founderCredFocus") }
        static var founderOffice: String { String(localized: "badge.founderOffice") }
        static var founderOfficePlace: String { String(localized: "badge.founderOfficePlace") }
    }
}
