import Foundation

extension L10n {
    enum Notification {
        static var intro: String { String(localized: "notification.intro") }
        static var empty: String { String(localized: "notification.empty") }
        static var emptyBody: String { String(localized: "notification.emptyBody") }
        static var markRead: String { String(localized: "notification.markRead") }
        static var title: String { String(localized: "notification.title") }
        static var matchTitle: String { String(localized: "notification.matchTitle") }
        static func matchBody(_ name: String) -> String {
            L10n.format("notification.matchBody", name)
        }
        static func messageTitle(_ name: String) -> String {
            L10n.format("notification.messageTitle", name)
        }
        static func messageRequestTitle(_ name: String) -> String {
            L10n.format("notification.messageRequestTitle", name)
        }
        static func commentTitle(_ name: String) -> String {
            L10n.format("notification.commentTitle", name)
        }
        static func postLikeTitle(_ name: String) -> String {
            L10n.format("notification.postLikeTitle", name)
        }
        static func storyLikeTitle(_ name: String) -> String {
            L10n.format("notification.storyLikeTitle", name)
        }
        static func meetingTitle(_ name: String) -> String {
            L10n.format("notification.meetingTitle", name)
        }
        static func meetingAcceptedTitle(_ name: String) -> String {
            L10n.format("notification.meetingAcceptedTitle", name)
        }
        static func meetingBody(_ place: String) -> String {
            L10n.format("notification.meetingBody", place)
        }
        static func meetingAcceptedBody(_ place: String) -> String {
            L10n.format("notification.meetingAcceptedBody", place)
        }
        static var clubTitle: String { String(localized: "notification.clubTitle") }
        static var loadFailed: String { String(localized: "notification.loadFailed") }
        static var updateFailed: String { String(localized: "notification.updateFailed") }
        static var bulkFailed: String { String(localized: "notification.bulkFailed") }
    }
}
