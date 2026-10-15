import Foundation

extension L10n {
    /// Sohbeti özelleştirme: ortak tema, hızlı tepki, yazı boyutu (1.1.5).
    enum ChatStyle {
        static var title: String { String(localized: "title", table: "ChatStyle") }
        static var theme: String { String(localized: "theme", table: "ChatStyle") }
        static var quickReaction: String { String(localized: "quickReaction", table: "ChatStyle") }
        static var quickReactionHint: String { String(localized: "quickReactionHint", table: "ChatStyle") }
        static var textSize: String { String(localized: "textSize", table: "ChatStyle") }
        static var textSizeHint: String { String(localized: "textSizeHint", table: "ChatStyle") }
        static var sharedHint: String { String(localized: "sharedHint", table: "ChatStyle") }
        static var sizeSmall: String { String(localized: "sizeSmall", table: "ChatStyle") }
        static var sizeNormal: String { String(localized: "sizeNormal", table: "ChatStyle") }
        static var sizeLarge: String { String(localized: "sizeLarge", table: "ChatStyle") }
        static var changeFailed: String { String(localized: "changeFailed", table: "ChatStyle") }
        static var previewTheirs: String { String(localized: "previewTheirs", table: "ChatStyle") }
        static var previewMine: String { String(localized: "previewMine", table: "ChatStyle") }
        static var moreEmoji: String { String(localized: "moreEmoji", table: "ChatStyle") }

        static func themeChangedMine(_ theme: String) -> String {
            String(format: String(localized: "themeChangedMine", table: "ChatStyle"), theme)
        }
        static func themeChangedTheirs(_ name: String, _ theme: String) -> String {
            String(format: String(localized: "themeChangedTheirs", table: "ChatStyle"), name, theme)
        }
        static func reactionChangedMine(_ emoji: String) -> String {
            String(format: String(localized: "reactionChangedMine", table: "ChatStyle"), emoji)
        }
        static func reactionChangedTheirs(_ name: String, _ emoji: String) -> String {
            String(format: String(localized: "reactionChangedTheirs", table: "ChatStyle"), name, emoji)
        }
        static func sendQuickReaction(_ emoji: String) -> String {
            String(format: String(localized: "sendQuickReaction", table: "ChatStyle"), emoji)
        }
    }
}
