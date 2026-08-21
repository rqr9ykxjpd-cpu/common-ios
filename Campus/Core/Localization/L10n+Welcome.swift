import Foundation

extension L10n {
    enum Welcome {
        static var headline: String { String(localized: "welcome.headline") }
        static var subtitle: String { String(localized: "welcome.subtitle") }
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
        static var canvasPostMeta: String { String(localized: "welcome.canvasPostMeta") }
        static var canvasCaption: String { String(localized: "welcome.canvasCaption") }
        static var canvasPlace: String { String(localized: "welcome.canvasPlace") }
        static var canvasChatMeta: String { String(localized: "welcome.canvasChatMeta") }
        static var canvasQuote: String { String(localized: "welcome.canvasQuote") }
    }
}
