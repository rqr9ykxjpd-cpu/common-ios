import Foundation

extension L10n {
    enum Edu {
        static var cardTitle: String { String(localized: "edu.cardTitle") }
        static var cardBody: String { String(localized: "edu.cardBody") }
        static var cardAction: String { String(localized: "edu.cardAction") }
        static var pendingTitle: String { String(localized: "edu.pendingTitle") }
        static func pendingBody(_ email: String) -> String { L10n.format("edu.pendingBody", email) }
        static var sheetTitle: String { String(localized: "edu.sheetTitle") }
        static var sheetHint: String { String(localized: "edu.sheetHint") }
        static var placeholder: String { String(localized: "edu.placeholder") }
        static var send: String { String(localized: "edu.send") }
        static var sentTitle: String { String(localized: "edu.sentTitle") }
        static func sentBody(_ email: String) -> String { L10n.format("edu.sentBody", email) }
        static var resend: String { String(localized: "edu.resend") }
        static func resendIn(_ seconds: Int) -> String { L10n.format("edu.resendIn", Int64(seconds)) }
        static var changeAddress: String { String(localized: "edu.changeAddress") }
        static var checkNow: String { String(localized: "edu.checkNow") }
        static var stillPending: String { String(localized: "edu.stillPending") }
        static var notAllowedDomain: String { String(localized: "edu.notAllowedDomain") }
        static var alreadyUsed: String { String(localized: "edu.alreadyUsed") }
        static var rateLimited: String { String(localized: "edu.rateLimited") }
        static var sendFailed: String { String(localized: "edu.sendFailed") }
        static var verifiedToast: String { String(localized: "edu.verifiedToast") }
        static var badge: String { String(localized: "edu.badge") }
        static var verifiedLine: String { String(localized: "edu.verifiedLine") }
        static var notNow: String { String(localized: "edu.notNow") }
    }
}
