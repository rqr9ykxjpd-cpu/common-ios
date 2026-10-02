import Foundation

extension L10n {
    /// Sohbette iki kişilik tepkiler.
    enum ChatReactions {
        static func theirs(_ emoji: String) -> String {
            String(format: String(localized: "theirs", table: "ChatReactions"), emoji)
        }
        static var pickerTitle: String { String(localized: "pickerTitle", table: "ChatReactions") }
        static var more: String { String(localized: "more", table: "ChatReactions") }
        static var recent: String { String(localized: "recent", table: "ChatReactions") }
        static var faces: String { String(localized: "faces", table: "ChatReactions") }
        static var gestures: String { String(localized: "gestures", table: "ChatReactions") }
        static var hearts: String { String(localized: "hearts", table: "ChatReactions") }
        static var fun: String { String(localized: "fun", table: "ChatReactions") }
        static var food: String { String(localized: "food", table: "ChatReactions") }
        static var animals: String { String(localized: "animals", table: "ChatReactions") }
        static var symbols: String { String(localized: "symbols", table: "ChatReactions") }
    }
}
