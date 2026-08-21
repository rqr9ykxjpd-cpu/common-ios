import Foundation

extension L10n {
    enum Auth {
        static var appleFailed: String { String(localized: "auth.appleFailed") }
        static var googleFailed: String { String(localized: "auth.googleFailed") }
        static var linkFailed: String { String(localized: "auth.linkFailed") }
        static var signInIncomplete: String { String(localized: "auth.signInIncomplete") }
        static var profileLoadFailed: String { String(localized: "auth.profileLoadFailed") }
        static var welcome: String { String(localized: "auth.welcome") }
        static func welcomeName(_ name: String) -> String {
            L10n.format("auth.welcomeName", name)
        }
        static var completeProfile: String { String(localized: "auth.completeProfile") }
        static var connectionFailed: String { String(localized: "auth.connectionFailed") }
        static var sessionRestoreFailed: String { String(localized: "auth.sessionRestoreFailed") }
        static var photosLoadFailed: String { String(localized: "auth.photosLoadFailed") }
        static var signOutFailed: String { String(localized: "auth.signOutFailed") }
        static var deleteFailed: String { String(localized: "auth.deleteFailed") }
    }
}
