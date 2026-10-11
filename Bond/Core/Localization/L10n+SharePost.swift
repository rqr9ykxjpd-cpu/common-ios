import Foundation

extension L10n {
    /// Gönderiyi sohbetten bir bağlantıya yollamak.
    enum SharePost {
        static var messageBody: String { String(localized: "messageBody", table: "SharePost") }
        static var previewMine: String { String(localized: "previewMine", table: "SharePost") }
        static var title: String { String(localized: "title", table: "SharePost") }
        static var send: String { String(localized: "send", table: "SharePost") }
        static var sent: String { String(localized: "sent", table: "SharePost") }
        static var search: String { String(localized: "search", table: "SharePost") }
        static var emptyTitle: String { String(localized: "emptyTitle", table: "SharePost") }
        static var emptyBody: String { String(localized: "emptyBody", table: "SharePost") }
        static var noResults: String { String(localized: "noResults", table: "SharePost") }
        static var footer: String { String(localized: "footer", table: "SharePost") }
        static var unavailable: String { String(localized: "unavailable", table: "SharePost") }
        static var openPost: String { String(localized: "openPost", table: "SharePost") }
        static var sendButton: String { String(localized: "sendButton", table: "SharePost") }
        static var photo: String { String(localized: "photo", table: "SharePost") }
    }
}
