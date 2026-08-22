import Foundation

extension L10n {
    enum Chat {
        static var loading: String { String(localized: "chat.loading") }
        static var title: String { String(localized: "chat.title") }
        static var oneRequest: String { String(localized: "chat.oneRequest") }
        static func requestCount(_ count: Int) -> String {
            L10n.format("chat.requestCount", Int64(count))
        }
        static var fromUnmatched: String { String(localized: "chat.fromUnmatched") }
        static var messages: String { String(localized: "chat.messages") }
        static var newConnections: String { String(localized: "chat.newConnections") }
        static var peopleToMeet: String { String(localized: "chat.peopleToMeet") }
        static var emptyTitle: String { String(localized: "chat.emptyTitle") }
        static var emptyBody: String { String(localized: "chat.emptyBody") }
        static var requestsIntro: String { String(localized: "chat.requestsIntro") }
        static var requestsTitle: String { String(localized: "chat.requestsTitle") }
        static var noRequests: String { String(localized: "chat.noRequests") }
        static var noRequestsBody: String { String(localized: "chat.noRequestsBody") }
        static var decline: String { String(localized: "chat.decline") }
        static var accept: String { String(localized: "chat.accept") }
        static var requestFootnote: String { String(localized: "chat.requestFootnote") }
        static var missing: String { String(localized: "chat.missing") }
        static var unmatchedMaybe: String { String(localized: "chat.unmatchedMaybe") }
        static var unmatchConfirm: String { String(localized: "chat.unmatchConfirm") }
        static var endMatch: String { String(localized: "chat.endMatch") }
        static var unmatchBody: String { String(localized: "chat.unmatchBody") }
        static var options: String { String(localized: "chat.options") }
        static var editing: String { String(localized: "chat.editing") }
        static var editingHint: String { String(localized: "chat.editingHint") }
        static var cancelEdit: String { String(localized: "chat.cancelEdit") }
        static var replyingToSelf: String { String(localized: "chat.replyingToSelf") }
        static var replying: String { String(localized: "chat.replying") }
        static var cancelReply: String { String(localized: "chat.cancelReply") }
        static var placeholder: String { String(localized: "chat.placeholder") }
        static var edited: String { String(localized: "chat.edited") }
        static var reply: String { String(localized: "chat.reply") }
        static var sendHeart: String { String(localized: "chat.sendHeart") }
        static func removeReaction(_ emoji: String) -> String {
            L10n.format("chat.removeReaction", emoji)
        }
        static func addReaction(_ emoji: String) -> String {
            L10n.format("chat.addReaction", emoji)
        }
        static var editLocked: String { String(localized: "chat.editLocked") }
        static func oneShared(_ interest: String) -> String {
            L10n.format("chat.oneShared", interest)
        }
        static func twoShared(_ a: String, _ b: String) -> String {
            L10n.format("chat.twoShared", a, b)
        }
        static func manyShared(_ a: String, _ b: String, _ count: Int) -> String {
            L10n.format("chat.manyShared", a, b, Int64(count))
        }
        static var newMatch: String { String(localized: "chat.newMatch") }
        static func blockConfirm(_ name: String) -> String {
            L10n.format("chat.blockConfirm", name)
        }
        static var blockBody: String { String(localized: "chat.blockBody") }
        static func blocked(_ name: String) -> String {
            L10n.format("chat.blocked", name)
        }
        static var blockFailed: String { String(localized: "chat.blockFailed") }
        static var matchEnded: String { String(localized: "chat.matchEnded") }
        static var unmatchFailed: String { String(localized: "chat.unmatchFailed") }
        static var reportReceived: String { String(localized: "chat.reportReceived") }
        static var reportFailed: String { String(localized: "chat.reportFailed") }
        static var requestsLoadFailed: String { String(localized: "chat.requestsLoadFailed") }
        static func requestIgnored(_ name: String) -> String {
            L10n.format("chat.requestIgnored", name)
        }
        static var dailyLimit: String { String(localized: "chat.dailyLimit") }
        static func alreadyRequested(_ name: String) -> String {
            L10n.format("chat.alreadyRequested", name)
        }
        static var requestSendFailed: String { String(localized: "chat.requestSendFailed") }
        static var acceptFailed: String { String(localized: "chat.acceptFailed") }
        static var declineFailed: String { String(localized: "chat.declineFailed") }
        static var loadFailed: String { String(localized: "chat.loadFailed") }
        static var sendFailed: String { String(localized: "chat.sendFailed") }
        static var deleteMessageConfirm: String { String(localized: "chat.deleteMessageConfirm") }
        static var deleteMessageBody: String { String(localized: "chat.deleteMessageBody") }
        static var deleteFailed: String { String(localized: "chat.deleteFailed") }
        static var editFailed: String { String(localized: "chat.editFailed") }
        static var reactionFailed: String { String(localized: "chat.reactionFailed") }
    }
}
