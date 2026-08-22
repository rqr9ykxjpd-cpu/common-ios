import Foundation

extension L10n {
    enum Feed {
        static func emptyPlace(_ place: String) -> String {
            L10n.format("feed.emptyPlace", place)
        }
        static var showAll: String { String(localized: "feed.showAll") }
        static var emptyTitle: String { String(localized: "feed.emptyTitle") }
        static var emptyMessage: String { String(localized: "feed.emptyMessage") }
        static var shareSomething: String { String(localized: "feed.shareSomething") }
        static var loading: String { String(localized: "feed.loading") }
        static var whereToMeet: String { String(localized: "feed.whereToMeet") }
        static var allPlaces: String { String(localized: "feed.allPlaces") }
        static func visibleAt(_ place: String) -> String {
            L10n.format("feed.visibleAt", place)
        }
        static func filteredBy(_ place: String) -> String {
            L10n.format("feed.filteredBy", place)
        }
        static func placeCount(_ count: Int) -> String {
            L10n.format("feed.placeCount", Int64(count))
        }
        static var clubsHeader: String { String(localized: "feed.clubsHeader") }
        static func notificationsA11y(_ count: Int) -> String {
            L10n.format("feed.notificationsA11y", Int64(count))
        }
        static var chatsA11y: String { String(localized: "feed.chatsA11y") }
        static var share: String { String(localized: "feed.share") }
        static var member: String { String(localized: "feed.member") }
        static func memberCount(_ count: Int) -> String {
            L10n.format("feed.memberCount", Int64(count))
        }
        static var yourStory: String { String(localized: "feed.yourStory") }
        static func openProfile(_ name: String) -> String {
            L10n.format("feed.openProfile", name)
        }
        static var deletePost: String { String(localized: "feed.deletePost") }
        static var deletePostConfirm: String { String(localized: "feed.deletePostConfirm") }
        static var blockUser: String { String(localized: "feed.blockUser") }
        static var like: String { String(localized: "feed.like") }
        static var unlike: String { String(localized: "feed.unlike") }
        static var save: String { String(localized: "feed.save") }
        static var removeSaved: String { String(localized: "feed.removeSaved") }
        static var openComments: String { String(localized: "feed.openComments") }
        static func likeCount(_ count: Int) -> String {
            L10n.format("feed.likeCount", Int64(count))
        }
        static var oneComment: String { String(localized: "feed.oneComment") }
        static func allComments(_ count: Int) -> String {
            L10n.format("feed.allComments", Int64(count))
        }
        static var irreversible: String { String(localized: "feed.irreversible") }
        static var loadFailed: String { String(localized: "feed.loadFailed") }
        static var likeFailed: String { String(localized: "feed.likeFailed") }
        static var postFailed: String { String(localized: "feed.postFailed") }
        static var saveFailed: String { String(localized: "feed.saveFailed") }
        static var savedLoadFailed: String { String(localized: "feed.savedLoadFailed") }
        static var postDeleted: String { String(localized: "feed.postDeleted") }
        static var deletePostFailed: String { String(localized: "feed.deletePostFailed") }
        static var commentFailed: String { String(localized: "feed.commentFailed") }
        static var commentDeleted: String { String(localized: "feed.commentDeleted") }
        static var deleteCommentFailed: String { String(localized: "feed.deleteCommentFailed") }
    }
}
