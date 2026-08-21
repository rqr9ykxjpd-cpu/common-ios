import Foundation

extension L10n {
    enum Story {
        static var missing: String { String(localized: "story.missing") }
        static var deleteConfirm: String { String(localized: "story.deleteConfirm") }
        static var delete: String { String(localized: "story.delete") }
        static var paused: String { String(localized: "story.paused") }
        static var pausePro: String { String(localized: "story.pausePro") }
        static var replyPlaceholder: String { String(localized: "story.replyPlaceholder") }
        static var sendRequest: String { String(localized: "story.sendRequest") }
        static var requestHint: String { String(localized: "story.requestHint") }
        static func replyTo(_ name: String) -> String {
            L10n.format("story.replyTo", name)
        }
        static var noViewers: String { String(localized: "story.noViewers") }
        static var noViewersBody: String { String(localized: "story.noViewersBody") }
        static func viewCount(_ count: Int) -> String {
            L10n.format("story.viewCount", Int64(count))
        }
        static var viewCountLocked: String { String(localized: "story.viewCountLocked") }
        static var viewersTitle: String { String(localized: "story.viewersTitle") }
        static var unlike: String { String(localized: "story.unlike") }
        static var like: String { String(localized: "story.like") }
        static var loadFailed: String { String(localized: "story.loadFailed") }
        static var postFailed: String { String(localized: "story.postFailed") }
        static var deleted: String { String(localized: "story.deleted") }
        static var deleteFailed: String { String(localized: "story.deleteFailed") }
        static var viewersLoadFailed: String { String(localized: "story.viewersLoadFailed") }
        static var likeFailed: String { String(localized: "story.likeFailed") }
        static var unlikeFailed: String { String(localized: "story.unlikeFailed") }
    }
}
