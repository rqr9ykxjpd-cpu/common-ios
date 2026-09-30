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
        static var gateActionTitle: String { String(localized: "gateActionTitle", table: "Support") }
        static var gateActionBody: String { String(localized: "gateActionBody", table: "Support") }
        static var gateWelcomeTitle: String { String(localized: "gateWelcomeTitle", table: "Support") }
        static var gateWelcomeBody: String { String(localized: "gateWelcomeBody", table: "Support") }
        static var gatePerkPost: String { String(localized: "gatePerkPost", table: "Support") }
        static var gatePerkMessage: String { String(localized: "gatePerkMessage", table: "Support") }
        static var gatePerkPlace: String { String(localized: "gatePerkPlace", table: "Support") }
        static var gateLater: String { String(localized: "gateLater", table: "Support") }
        static var browseBanner: String { String(localized: "browseBanner", table: "Support") }
        static var browseAction: String { String(localized: "browseAction", table: "Support") }
        static var lockedTitle: String { String(localized: "lockedTitle", table: "Support") }
        static var lockedBody: String { String(localized: "lockedBody", table: "Support") }
        static var gateToggle: String { String(localized: "gateToggle", table: "Support") }
        static var gateToggleHint: String { String(localized: "gateToggleHint", table: "Support") }
        static var gateTurnOn: String { String(localized: "gateTurnOn", table: "Support") }
        static var gateTurnOff: String { String(localized: "gateTurnOff", table: "Support") }
        static var gateConfirmOff: String { String(localized: "gateConfirmOff", table: "Support") }
        static func gateConfirmOn(_ n: Int) -> String {
            String(format: String(localized: "gateConfirmOn", table: "Support"), Int64(n))
        }
        static var filterAll: String { String(localized: "filterAll", table: "Support") }
        static var filterUnverified: String { String(localized: "filterUnverified", table: "Support") }
        static var unverifiedEmpty: String { String(localized: "unverifiedEmpty", table: "Support") }
        static var verifyStudent: String { String(localized: "verifyStudent", table: "Support") }
        static var unverifyStudent: String { String(localized: "unverifyStudent", table: "Support") }
        static func replyCount(_ n: Int) -> String {
            String(format: String(localized: "replyCount", table: "Support"), Int64(n))
        }
        static func usersOnline(_ n: Int) -> String {
            String(format: String(localized: "usersOnline", table: "Support"), Int64(n))
        }
    }
}
