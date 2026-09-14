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
        static var statsUsers: String { String(localized: "founder.stats.users", table: "Board") }
        static var statsPlans: String { String(localized: "founder.stats.plans", table: "Board") }
        static var statsBoard: String { String(localized: "founder.stats.board", table: "Board") }
        static var statsPeople: String { String(localized: "founder.stats.people", table: "Board") }
        /// Dinamik anahtar: String(localized:) derleme zamanı anahtar istiyor,
        /// çalışma zamanında üretilen anahtarı bulamayıp anahtarın kendisini basıyordu.
        static func stat(_ key: String) -> String {
            Bundle.main.localizedString(forKey: "founder.stat.\(key)", value: nil, table: "Board")
        }
        static var swipedRight: String { String(localized: "founder.swipedRight", table: "Board") }
        static var swipedLeft: String { String(localized: "founder.swipedLeft", table: "Board") }
        static var swiperMatched: String { String(localized: "founder.swiperMatched", table: "Board") }
    }
}
