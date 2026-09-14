import Foundation

extension L10n {
    enum AccountDeletion {
        static var reauthorizeBody: String { String(localized: "reauthorizeBody", table: "AccountDeletion") }
        static var subscriptionReminder: String { String(localized: "subscriptionReminder", table: "AccountDeletion") }
        static var manualBody: String { String(localized: "manualBody", table: "AccountDeletion") }
        static var manualDelete: String { String(localized: "manualDelete", table: "AccountDeletion") }
        static var manualConfirmBody: String { String(localized: "manualConfirmBody", table: "AccountDeletion") }
        static var appleInstructions: String { String(localized: "appleInstructions", table: "AccountDeletion") }
        static var deletedTitle: String { String(localized: "deletedTitle", table: "AccountDeletion") }
        static var deletedManualBody: String { String(localized: "deletedManualBody", table: "AccountDeletion") }
        static var revokeFailed: String { String(localized: "revokeFailed", table: "AccountDeletion") }
        static var wrongAppleAccount: String { String(localized: "wrongAppleAccount", table: "AccountDeletion") }
        static var cancelled: String { String(localized: "cancelled", table: "AccountDeletion") }
        static var revokedRetryBody: String { String(localized: "revokedRetryBody", table: "AccountDeletion") }
    }
}
