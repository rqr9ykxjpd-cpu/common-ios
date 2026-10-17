import Foundation

extension L10n {
    /// Mesajın durumu, iPhone Mesajlar'daki gibi (1.1.7).
    enum MessageStatus {
        static var delivered: String { String(localized: "delivered", table: "MessageStatus") }
        static var notDelivered: String { String(localized: "notDelivered", table: "MessageStatus") }
        static var notDeliveredBody: String { String(localized: "notDeliveredBody", table: "MessageStatus") }
        static var tryAgain: String { String(localized: "tryAgain", table: "MessageStatus") }
        static var deleteMessage: String { String(localized: "deleteMessage", table: "MessageStatus") }
    }
}
