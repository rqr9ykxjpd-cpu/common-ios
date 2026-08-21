import Foundation

extension L10n {
    enum Moderation {
        static var noneWaiting: String { String(localized: "moderation.noneWaiting") }
        static func waitingCount(_ count: Int) -> String {
            L10n.format("moderation.waitingCount", Int64(count))
        }
        static var loading: String { String(localized: "moderation.loading") }
        static var title: String { String(localized: "moderation.title") }
        static var reopenTitle: String { String(localized: "moderation.reopenTitle") }
        static var reopen: String { String(localized: "moderation.reopen") }
        static func reopenBody(_ name: String) -> String {
            L10n.format("moderation.reopenBody", name)
        }
        static var empty: String { String(localized: "moderation.empty") }
        static var emptyBody: String { String(localized: "moderation.emptyBody") }
        static var pending: String { String(localized: "moderation.pending") }
        static var closed: String { String(localized: "moderation.closed") }
        static var suspended: String { String(localized: "moderation.suspended") }
        static func reporter(_ name: String) -> String {
            L10n.format("moderation.reporter", name)
        }
        static var unknown: String { String(localized: "moderation.unknown") }
        static var noIssue: String { String(localized: "moderation.noIssue") }
        static var removedContent: String { String(localized: "moderation.removedContent") }
        static var suspend: String { String(localized: "moderation.suspend") }
        static var suspendHint: String { String(localized: "moderation.suspendHint") }
        static var resultRemoved: String { String(localized: "moderation.resultRemoved") }
        static var resultSuspended: String { String(localized: "moderation.resultSuspended") }
        static var resultClear: String { String(localized: "moderation.resultClear") }
        static var loadFailed: String { String(localized: "moderation.loadFailed") }
        static var closeFailed: String { String(localized: "moderation.closeFailed") }
        static var reopenFailed: String { String(localized: "moderation.reopenFailed") }
        static var postRemoved: String { String(localized: "moderation.postRemoved") }
        static var removeFailed: String { String(localized: "moderation.removeFailed") }
    }
}
