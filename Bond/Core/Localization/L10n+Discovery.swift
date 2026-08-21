import Foundation

extension L10n {
    enum Discovery {
        static var meetStamp: String { String(localized: "discovery.meetStamp") }
        static var passStamp: String { String(localized: "discovery.passStamp") }
        static var title: String { String(localized: "discovery.title") }
        static var subtitle: String { String(localized: "discovery.subtitle") }
        static var filtersA11y: String { String(localized: "discovery.filtersA11y") }
        static func filtersActiveA11y(_ count: Int) -> String {
            L10n.format("discovery.filtersActiveA11y", Int64(count))
        }
        static var chats: String { String(localized: "discovery.chats") }
        static var swipePass: String { String(localized: "discovery.swipePass") }
        static var swipeMeet: String { String(localized: "discovery.swipeMeet") }
        static var pass: String { String(localized: "discovery.pass") }
        static var meet: String { String(localized: "discovery.meet") }
        static var seeFullProfile: String { String(localized: "discovery.seeFullProfile") }
        static var preparing: String { String(localized: "discovery.preparing") }
        static var noFilterMatches: String { String(localized: "discovery.noFilterMatches") }
        static var deckEmpty: String { String(localized: "discovery.deckEmpty") }
        static func filtersOpen(_ count: Int) -> String {
            L10n.format("discovery.filtersOpen", Int64(count))
        }
        static var clearFilters: String { String(localized: "discovery.clearFilters") }
        static var editFilters: String { String(localized: "discovery.editFilters") }
        static var emptyHint: String { String(localized: "discovery.emptyHint") }
        static var ageRange: String { String(localized: "discovery.ageRange") }
        static func minAge(_ age: Int) -> String {
            L10n.format("discovery.minAge", Int64(age))
        }
        static func maxAge(_ age: Int) -> String {
            L10n.format("discovery.maxAge", Int64(age))
        }
        static var yearSection: String { String(localized: "discovery.yearSection") }
        static var departmentSection: String { String(localized: "discovery.departmentSection") }
        static var priorities: String { String(localized: "discovery.priorities") }
        static var commonInterest: String { String(localized: "discovery.commonInterest") }
        static var sameCampus: String { String(localized: "discovery.sameCampus") }
        static var filterTitle: String { String(localized: "discovery.filterTitle") }
        static var apply: String { String(localized: "discovery.apply") }
        static func compatibility(_ score: Int) -> String {
            L10n.format("discovery.compatibility", Int64(score))
        }
        static var whyCompatible: String { String(localized: "discovery.whyCompatible") }
        static var interests: String { String(localized: "discovery.interests") }
        static var visibleNow: String { String(localized: "discovery.visibleNow") }
        static var theirPosts: String { String(localized: "discovery.theirPosts") }
        static var safety: String { String(localized: "discovery.safety") }
        static var prevPhoto: String { String(localized: "discovery.prevPhoto") }
        static var nextPhoto: String { String(localized: "discovery.nextPhoto") }
        static var matchEyebrowBrand: String { String(localized: "discovery.matchEyebrowBrand") }
        static var matchEyebrow: String { String(localized: "discovery.matchEyebrow") }
        static func matchTitle(_ name: String) -> String {
            L10n.format("discovery.matchTitle", name)
        }
        static var matchSubtitle: String { String(localized: "discovery.matchSubtitle") }
        static func starterCampus(_ interest: String) -> String {
            L10n.format("discovery.starterCampus", interest)
        }
        static func starterHow(_ interest: String) -> String {
            L10n.format("discovery.starterHow", interest)
        }
        static var starterCorner: String { String(localized: "discovery.starterCorner") }
        static var starterHello: String { String(localized: "discovery.starterHello") }
        static var writeOwn: String { String(localized: "discovery.writeOwn") }
        static var backToDeck: String { String(localized: "discovery.backToDeck") }
        static var missingAvatar: String { String(localized: "discovery.missingAvatar") }
        static var missingGallery: String { String(localized: "discovery.missingGallery") }
        static var missingName: String { String(localized: "discovery.missingName") }
        static var missingDepartment: String { String(localized: "discovery.missingDepartment") }
        static var missingBio: String { String(localized: "discovery.missingBio") }
        static var missingInterests: String { String(localized: "discovery.missingInterests") }
        static var cardComplete: String { String(localized: "discovery.cardComplete") }
        static var yourCard: String { String(localized: "discovery.yourCard") }
        static var cardSubtitle: String { String(localized: "discovery.cardSubtitle") }
        static var missingHeader: String { String(localized: "discovery.missingHeader") }
        static var missingFooter: String { String(localized: "discovery.missingFooter") }
        static var sameYear: String { String(localized: "discovery.sameYear") }
        static func commonInterests(_ count: Int) -> String {
            L10n.format("discovery.commonInterests", Int64(count))
        }
        static var rewindFailed: String { String(localized: "discovery.rewindFailed") }
        static var loadFailed: String { String(localized: "discovery.loadFailed") }
        static var actionFailed: String { String(localized: "discovery.actionFailed") }
    }
}
