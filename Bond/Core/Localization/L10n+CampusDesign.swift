import Foundation

extension L10n {
    enum CampusDesign {
        static var today: String { String(localized: "today", table: "CampusDesign") }
        static var clubsHint: String { String(localized: "clubsHint", table: "CampusDesign") }
        static var viewProfile: String { String(localized: "viewProfile", table: "CampusDesign") }
        static var samePlace: String { String(localized: "samePlace", table: "CampusDesign") }
        static var requestTitle: String { String(localized: "requestTitle", table: "CampusDesign") }
        static var requestCTA: String { String(localized: "requestCTA", table: "CampusDesign") }
        static var requestHint: String { String(localized: "requestHint", table: "CampusDesign") }
        static var requestPlaceholder: String { String(localized: "requestPlaceholder", table: "CampusDesign") }
        static var requestSent: String { String(localized: "requestSent", table: "CampusDesign") }
        static var requestFailure: String { String(localized: "requestFailure", table: "CampusDesign") }
        static var shared: String { String(localized: "shared", table: "CampusDesign") }
        static var about: String { String(localized: "about", table: "CampusDesign") }
        static var compare: String { String(localized: "compare", table: "CampusDesign") }
        static var benefits: String { String(localized: "benefits", table: "CampusDesign") }
        static var plusPosts: String { String(localized: "plusPosts", table: "CampusDesign") }
        static var plusVisitors: String { String(localized: "plusVisitors", table: "CampusDesign") }
        static var plusMessages: String { String(localized: "plusMessages", table: "CampusDesign") }
        static var proRequests: String { String(localized: "proRequests", table: "CampusDesign") }
        static var proStories: String { String(localized: "proStories", table: "CampusDesign") }
        static var expandPhoto: String { String(localized: "expandPhoto", table: "CampusDesign") }
        static var proGhost: String { String(localized: "proGhost", table: "CampusDesign") }
        static var choosePlan: String { String(localized: "choosePlan", table: "CampusDesign") }
        static var weekly: String { String(localized: "weekly", table: "CampusDesign") }
        static var priceLoading: String { String(localized: "priceLoading", table: "CampusDesign") }
        static var retryPrices: String { String(localized: "retryPrices", table: "CampusDesign") }
        static var manualPlace: String { String(localized: "manualPlace", table: "CampusDesign") }
        static func remaining(_ minutes: Int) -> String { String(format: String(localized: "remaining", table: "CampusDesign"), locale: L10n.appLocale, Int64(minutes)) }
        static var refreshPresence: String { String(localized: "refreshPresence", table: "CampusDesign") }
        static var presenceExpired: String { String(localized: "presenceExpired", table: "CampusDesign") }
        static var presenceLoading: String { String(localized: "presenceLoading", table: "CampusDesign") }
        static var photoSwipeHint: String { String(localized: "photoSwipeHint", table: "CampusDesign") }
        static var photoTapHint: String { String(localized: "photoTapHint", table: "CampusDesign") }
        static var nextPhoto: String { String(localized: "nextPhoto", table: "CampusDesign") }
        static var previousPhoto: String { String(localized: "previousPhoto", table: "CampusDesign") }
        static var cardSwipeHint: String { String(localized: "cardSwipeHint", table: "CampusDesign") }
        static var cardRequestSentHint: String { String(localized: "cardRequestSentHint", table: "CampusDesign") }
        static var cardSwipeHintSelf: String { String(localized: "cardSwipeHintSelf", table: "CampusDesign") }
        static var swipeRequestStamp: String { String(localized: "swipeRequestStamp", table: "CampusDesign") }
        static var swipePassStamp: String { String(localized: "swipePassStamp", table: "CampusDesign") }
        static var swipeRequestBody: String { String(localized: "swipeRequestBody", table: "CampusDesign") }
        static var alreadySwiped: String { String(localized: "alreadySwiped", table: "CampusDesign") }
        static var rightSwipeSent: String { String(localized: "rightSwipeSent", table: "CampusDesign") }
        static var rightSwipeUndone: String { String(localized: "rightSwipeUndone", table: "CampusDesign") }
        static var rightSwipeUndoFailed: String { String(localized: "rightSwipeUndoFailed", table: "CampusDesign") }
        static var rightSwipeMatched: String { String(localized: "rightSwipeMatched", table: "CampusDesign") }
        static var rightSwipeFailed: String { String(localized: "rightSwipeFailed", table: "CampusDesign") }
        static func photoIndex(_ current: Int, of total: Int) -> String {
            String(format: String(localized: "photoIndex", table: "CampusDesign"), locale: L10n.appLocale, Int64(current), Int64(total))
        }
    }
}
