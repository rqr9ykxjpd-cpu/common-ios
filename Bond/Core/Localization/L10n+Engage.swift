import Foundation

extension L10n {
    /// Bildirim iznini doğru anda istemek ve daveti öne çıkarmak (1.1.5).
    enum Engage {
        static var pushAskTitle: String { String(localized: "pushAskTitle", table: "Engage") }
        static var pushAskMessage: String { String(localized: "pushAskMessage", table: "Engage") }
        static var pushAskConnection: String { String(localized: "pushAskConnection", table: "Engage") }
        static var pushAskPost: String { String(localized: "pushAskPost", table: "Engage") }
        static var pushAskGroup: String { String(localized: "pushAskGroup", table: "Engage") }
        static var pushAskEvent: String { String(localized: "pushAskEvent", table: "Engage") }
        static var pushAskAllow: String { String(localized: "pushAskAllow", table: "Engage") }
        static var pushAskLater: String { String(localized: "pushAskLater", table: "Engage") }
        static var pushOffTitle: String { String(localized: "pushOffTitle", table: "Engage") }
        static var pushOffBody: String { String(localized: "pushOffBody", table: "Engage") }
        static var pushOffAction: String { String(localized: "pushOffAction", table: "Engage") }
        static var pushOffDismiss: String { String(localized: "pushOffDismiss", table: "Engage") }
        static var chatsInviteTitle: String { String(localized: "chatsInviteTitle", table: "Engage") }
    }
}
