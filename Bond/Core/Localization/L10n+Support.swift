import Foundation

extension L10n {
    /// Destek talepleri ve kurucunun kullanıcı listesindeki ekler.
    enum Support {
        static var inboxTitle: String { String(localized: "inboxTitle", table: "Support") }
        static var inboxHint: String { String(localized: "inboxHint", table: "Support") }
        static var threadTitle: String { String(localized: "threadTitle", table: "Support") }
        static var emptyTitle: String { String(localized: "emptyTitle", table: "Support") }
        static var emptyBody: String { String(localized: "emptyBody", table: "Support") }
        static var statusOpen: String { String(localized: "statusOpen", table: "Support") }
        static var statusOpenStaff: String { String(localized: "statusOpenStaff", table: "Support") }
        static var statusAnswered: String { String(localized: "statusAnswered", table: "Support") }
        static var statusResolved: String { String(localized: "statusResolved", table: "Support") }
        static var staffName: String { String(localized: "staffName", table: "Support") }
        static var you: String { String(localized: "you", table: "Support") }
        static var placeholder: String { String(localized: "placeholder", table: "Support") }
        static var sendA11y: String { String(localized: "sendA11y", table: "Support") }
        static var resolveAndNotify: String { String(localized: "resolveAndNotify", table: "Support") }
        static var resolvedNote: String { String(localized: "resolvedNote", table: "Support") }
        static var reply: String { String(localized: "reply", table: "Support") }
        static var sendFailed: String { String(localized: "sendFailed", table: "Support") }
        static var loadFailed: String { String(localized: "loadFailed", table: "Support") }
        static var notifAnswered: String { String(localized: "notifAnswered", table: "Support") }
        static var notifResolved: String { String(localized: "notifResolved", table: "Support") }
        static var usersOnlineNone: String { String(localized: "usersOnlineNone", table: "Support") }
        static var online: String { String(localized: "online", table: "Support") }
        static var eduExempt: String { String(localized: "eduExempt", table: "Support") }
        static var makeExempt: String { String(localized: "makeExempt", table: "Support") }
        static var removeExempt: String { String(localized: "removeExempt", table: "Support") }
        static var openProfile: String { String(localized: "openProfile", table: "Support") }
        static var pushOn: String { String(localized: "pushOn", table: "Support") }
        static var pushOff: String { String(localized: "pushOff", table: "Support") }
        static func pushCount(_ n: Int) -> String {
            String(format: String(localized: "pushCount", table: "Support"), Int64(n))
        }
        static func replyCount(_ n: Int) -> String {
            String(format: String(localized: "replyCount", table: "Support"), Int64(n))
        }
        static func usersOnline(_ n: Int) -> String {
            String(format: String(localized: "usersOnline", table: "Support"), Int64(n))
        }
    }
}
