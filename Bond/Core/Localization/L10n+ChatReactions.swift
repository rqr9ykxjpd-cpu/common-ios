import Foundation

extension L10n {
    /// Sohbette iki kişilik tepkiler.
    enum ChatReactions {
        static func theirs(_ emoji: String) -> String {
            String(format: String(localized: "theirs", table: "ChatReactions"), emoji)
        }
    }
}
