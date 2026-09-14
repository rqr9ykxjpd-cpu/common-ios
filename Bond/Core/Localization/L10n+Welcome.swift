import Foundation

extension L10n {
    enum Welcome {
        static var headline: String { String(localized: "welcome.headline") }
        static var handNote: String { String(localized: "welcome.handNote") }
        static var featureShareTitle: String { String(localized: "welcome.featureShareTitle") }
        static var featureShareBody: String { String(localized: "welcome.featureShareBody") }
        static var featureClubsTitle: String { String(localized: "welcome.featureClubsTitle") }
        static var featureClubsBody: String { String(localized: "welcome.featureClubsBody") }
        static var featureOfflineTitle: String { String(localized: "welcome.featureOfflineTitle") }
        static var featureOfflineBody: String { String(localized: "welcome.featureOfflineBody") }
        static var googleContinue: String { String(localized: "welcome.googleContinue") }
        static var emailContinue: String { String(localized: "welcome.emailContinue") }
        static func legalConsent(_ terms: String, _ privacy: String) -> String {
            L10n.format("welcome.legalConsent", terms, privacy)
        }
        static var appleIncomplete: String { String(localized: "welcome.appleIncomplete") }
        static var googleIncomplete: String { String(localized: "welcome.googleIncomplete") }
        static var emailTitle: String { String(localized: "welcome.emailTitle") }
        static var emailSubtitle: String { String(localized: "welcome.emailSubtitle") }
        static var emailPasswordSubtitle: String { String(localized: "welcome.emailPasswordSubtitle") }
        static var emailPlaceholder: String { String(localized: "welcome.emailPlaceholder") }
        static var passwordPlaceholder: String { String(localized: "welcome.passwordPlaceholder") }
        static var signInWithPassword: String { String(localized: "welcome.signInWithPassword") }
        static var sendLink: String { String(localized: "welcome.sendLink") }
        static var checkInbox: String { String(localized: "welcome.checkInbox") }
        static func linkSent(_ email: String) -> String {
            L10n.format("welcome.linkSent", email)
        }
        static var tryDifferentEmail: String { String(localized: "welcome.tryDifferentEmail") }
        static var signingIn: String { String(localized: "welcome.signingIn") }
    }
}
