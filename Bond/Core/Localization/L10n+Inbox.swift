import Foundation

extension L10n {
    /// Bildirim ve sohbet silme (1.1.1).
    enum Inbox {
        static var deleteAll: String { String(localized: "deleteAll", table: "Inbox") }
        static var deleteAllConfirm: String { String(localized: "deleteAllConfirm", table: "Inbox") }
        static var deleteAllBody: String { String(localized: "deleteAllBody", table: "Inbox") }
        static var deleteFailed: String { String(localized: "deleteFailed", table: "Inbox") }
        static var chatDeleted: String { String(localized: "chatDeleted", table: "Inbox") }
        static var clearChat: String { String(localized: "clearChat", table: "Inbox") }
        static func clearChatConfirm(_ name: String) -> String {
            String(format: String(localized: "clearChatConfirm", table: "Inbox"), name)
        }
        static var clearChatBody: String { String(localized: "clearChatBody", table: "Inbox") }
        static var clearFailed: String { String(localized: "clearFailed", table: "Inbox") }
        static var chatCleared: String { String(localized: "chatCleared", table: "Inbox") }
        static var removeAndDelete: String { String(localized: "removeAndDelete", table: "Inbox") }
        static func removeAndDeleteConfirm(_ name: String) -> String {
            String(format: String(localized: "removeAndDeleteConfirm", table: "Inbox"), name)
        }
        static var removeAndDeleteBody: String { String(localized: "removeAndDeleteBody", table: "Inbox") }
    }
}
