import Foundation

extension L10n {
    enum Welcome {
        static var headline: String { String(localized: "welcome.headline") }
        static var featureShareTitle: String { String(localized: "welcome.featureShareTitle") }
        static var featureShareBody: String { String(localized: "welcome.featureShareBody") }
        static var featureMeetTitle: String { String(localized: "welcome.featureMeetTitle") }
        static var featureMeetBody: String { String(localized: "welcome.featureMeetBody") }
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
        static var emailPlaceholder: String { String(localized: "welcome.emailPlaceholder") }
        static var sendLink: String { String(localized: "welcome.sendLink") }
        static var checkInbox: String { String(localized: "welcome.checkInbox") }
        static func linkSent(_ email: String) -> String {
            L10n.format("welcome.linkSent", email)
        }
        static var tryDifferentEmail: String { String(localized: "welcome.tryDifferentEmail") }
    }
}
