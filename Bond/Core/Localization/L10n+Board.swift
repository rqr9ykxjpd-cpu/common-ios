import Foundation

extension L10n {
    /// Reddit modeli akış: oy, cevap, sıralama.
    enum Board {
        static var popular: String { String(localized: "sort.popular", table: "Board") }
        static var newest: String { String(localized: "sort.newest", table: "Board") }
        static var sortA11y: String { String(localized: "sort.a11y", table: "Board") }

        static var vote: String { String(localized: "vote.up", table: "Board") }
        static var unvote: String { String(localized: "vote.undo", table: "Board") }
        static var downvote: String { String(localized: "vote.down", table: "Board") }
        static var undoDownvote: String { String(localized: "vote.undoDown", table: "Board") }
        static func voteCount(_ count: Int) -> String { format("vote.count", count) }

        static func answerCount(_ count: Int) -> String { format("answers.count", count) }
        static func commentCount(_ count: Int) -> String { format("comments.count", count) }

        private static func format(_ key: String.LocalizationValue, _ count: Int) -> String {
            String(format: String(localized: key, table: "Board"), locale: L10n.appLocale, Int64(count))
        }
        private static func format(_ key: String.LocalizationValue, _ text: String) -> String {
            String(format: String(localized: key, table: "Board"), locale: L10n.appLocale, text)
        }
        static var answersTitle: String { String(localized: "answers.title", table: "Board") }
        static var answerPlaceholder: String { String(localized: "answers.placeholder", table: "Board") }
        static var answersEmpty: String { String(localized: "answers.empty", table: "Board") }
        static var answersEmptyBody: String { String(localized: "answers.emptyBody", table: "Board") }
        static var topAnswer: String { String(localized: "answers.top", table: "Board") }
        static var openPost: String { String(localized: "post.open", table: "Board") }

        // Kurucu araçları
        static var boostTitle: String { String(localized: "founder.boost", table: "Board") }
        static var boostPrompt: String { String(localized: "founder.boostPrompt", table: "Board") }
        static var boostPlaceholder: String { String(localized: "founder.boostPlaceholder", table: "Board") }
        static var boostApply: String { String(localized: "founder.boostApply", table: "Board") }
        static var boostClear: String { String(localized: "founder.boostClear", table: "Board") }
        static func boostCurrent(_ count: Int) -> String { format("founder.boostCurrent", count) }
        static var pin: String { String(localized: "founder.pin", table: "Board") }
        static var unpin: String { String(localized: "founder.unpin", table: "Board") }
        static var pinned: String { String(localized: "founder.pinned", table: "Board") }
        static func pinnedAt(_ slot: Int) -> String { format("founder.pinnedAt", slot) }
        static var pinChange: String { String(localized: "founder.pinChange", table: "Board") }
        static var pinPrompt: String { String(localized: "founder.pinPrompt", table: "Board") }
        static var pinPlaceholder: String { String(localized: "founder.pinPlaceholder", table: "Board") }
        static var pinApply: String { String(localized: "founder.pinApply", table: "Board") }
        static var voters: String { String(localized: "founder.voters", table: "Board") }
        static var votersEmpty: String { String(localized: "founder.votersEmpty", table: "Board") }
        static var founderActionFailed: String { String(localized: "founder.failed", table: "Board") }
        static var swipersTitle: String { String(localized: "founder.swipers", table: "Board") }
        static var swipersHint: String { String(localized: "founder.swipersHint", table: "Board") }
        static var swipersEmpty: String { String(localized: "founder.swipersEmpty", table: "Board") }
        static var statsTitle: String { String(localized: "founder.stats", table: "Board") }
        static var statsHint: String { String(localized: "founder.statsHint", table: "Board") }
        static var statsLive: String { String(localized: "founder.stats.live", table: "Board") }
        static var broadcastTitle: String { String(localized: "founder.broadcast", table: "Board") }
        static var broadcastHint: String { String(localized: "founder.broadcastHint", table: "Board") }
        static var broadcastTitleField: String { String(localized: "founder.broadcastTitleField", table: "Board") }
        static var broadcastBodyField: String { String(localized: "founder.broadcastBodyField", table: "Board") }
        static var broadcastTest: String { String(localized: "founder.broadcastTest", table: "Board") }
        static func broadcastSend(_ count: Int) -> String { format("founder.broadcastSend", count) }
        static func broadcastConfirm(_ count: Int) -> String { format("founder.broadcastConfirm", count) }
        static func broadcastDone(_ count: Int) -> String { format("founder.broadcastDone", count) }
        static var broadcastTestDone: String { String(localized: "founder.broadcastTestDone", table: "Board") }
        static var week: String { String(localized: "founder.week", table: "Board") }
        static var weekNew: String { String(localized: "founder.week.newUsers", table: "Board") }
        static var weekActive: String { String(localized: "founder.week.active", table: "Board") }
        static var weekPosts: String { String(localized: "founder.week.posts", table: "Board") }
        static var users: String { String(localized: "founder.users", table: "Board") }
        static var usersHint: String { String(localized: "founder.usersHint", table: "Board") }
        static var usersSearch: String { String(localized: "founder.usersSearch", table: "Board") }
        static var usersEmpty: String { String(localized: "founder.usersEmpty", table: "Board") }
        static func userJoined(_ when: String) -> String { format("founder.user.joined", when) }
        static func userActive(_ when: String) -> String { format("founder.user.active", when) }
        static var userFrozen: String { String(localized: "founder.user.frozen", table: "Board") }
        static var userActions: String { String(localized: "founder.user.actions", table: "Board") }
        static var userOpenProfile: String { String(localized: "founder.user.openProfile", table: "Board") }
        static var giftPlus30: String { String(localized: "founder.user.giftPlus30", table: "Board") }
        static var giftPro30: String { String(localized: "founder.user.giftPro30", table: "Board") }
        static var giftProForever: String { String(localized: "founder.user.giftProForever", table: "Board") }
        static var removeGift: String { String(localized: "founder.user.removeGift", table: "Board") }
        static var makeModerator: String { String(localized: "founder.user.makeModerator", table: "Board") }
        static var removeModerator: String { String(localized: "founder.user.removeModerator", table: "Board") }
        static var freeze: String { String(localized: "founder.user.freeze", table: "Board") }
        static var unfreeze: String { String(localized: "founder.user.unfreeze", table: "Board") }
        static func freezeConfirm(_ name: String) -> String { format("founder.user.freezeConfirm", name) }
        static var paidPlan: String { String(localized: "founder.user.paidPlan", table: "Board") }
        static var userDone: String { String(localized: "founder.user.done", table: "Board") }
        static var announcements: String { String(localized: "founder.announcements", table: "Board") }
        static var announcementsEmpty: String { String(localized: "founder.announcementsEmpty", table: "Board") }
        static func announcementRecipients(_ n: Int) -> String { format("founder.announcement.recipients", n) }
        static var statsUsers: String { String(localized: "founder.stats.users", table: "Board") }
        static var statsPlans: String { String(localized: "founder.stats.plans", table: "Board") }
        static var statsBoard: String { String(localized: "founder.stats.board", table: "Board") }
        static var statsPeople: String { String(localized: "founder.stats.people", table: "Board") }
        /// Dinamik anahtar: String(localized:) derleme zamanı anahtar istiyor,
        /// çalışma zamanında üretilen anahtarı bulamayıp anahtarın kendisini basıyordu.
        static func stat(_ key: String) -> String {
            Bundle.main.localizedString(forKey: "founder.stat.\(key)", value: nil, table: "Board")
        }
        static func chip(_ key: String) -> String {
            Bundle.main.localizedString(forKey: "founder.chip.\(key)", value: nil, table: "Board")
        }
        static var swipedRight: String { String(localized: "founder.swipedRight", table: "Board") }
        static var swipedLeft: String { String(localized: "founder.swipedLeft", table: "Board") }
        static var swiperMatched: String { String(localized: "founder.swiperMatched", table: "Board") }
    }
}
