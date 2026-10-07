import Foundation

extension L10n {
    /// Kulüp yöneticileri ve kulüp hesabına geçiş.
    enum ClubSwitch {
        static func switchToClub(_ value: String) -> String {
            String(format: String(localized: "switchToClub", table: "ClubSwitch"), value)
        }
        static var switchToClubHint: String { String(localized: "switchToClubHint", table: "ClubSwitch") }
        static var switchToMain: String { String(localized: "switchToMain", table: "ClubSwitch") }
        static func switchToMainHint(_ value: String) -> String {
            String(format: String(localized: "switchToMainHint", table: "ClubSwitch"), value)
        }
        static func switchingTo(_ value: String) -> String {
            String(format: String(localized: "switchingTo", table: "ClubSwitch"), value)
        }
        static var switchingBack: String { String(localized: "switchingBack", table: "ClubSwitch") }
        static func switched(_ value: String) -> String {
            String(format: String(localized: "switched", table: "ClubSwitch"), value)
        }
        static var backToMain: String { String(localized: "backToMain", table: "ClubSwitch") }
        static var failed: String { String(localized: "failed", table: "ClubSwitch") }
        static var notManager: String { String(localized: "notManager", table: "ClubSwitch") }
        static var noLongerManager: String { String(localized: "noLongerManager", table: "ClubSwitch") }
        static var mainSessionLost: String { String(localized: "mainSessionLost", table: "ClubSwitch") }
        static var noPurchases: String { String(localized: "noPurchases", table: "ClubSwitch") }
        static var clubAccountNote: String { String(localized: "clubAccountNote", table: "ClubSwitch") }
        static var makeManager: String { String(localized: "makeManager", table: "ClubSwitch") }
        static var managerTitle: String { String(localized: "managerTitle", table: "ClubSwitch") }
        static var managerHint: String { String(localized: "managerHint", table: "ClubSwitch") }
        static var managerOn: String { String(localized: "managerOn", table: "ClubSwitch") }
        static var clubAccountRow: String { String(localized: "clubAccountRow", table: "ClubSwitch") }
        static var accountLoadFailed: String { String(localized: "accountLoadFailed", table: "ClubSwitch") }
        static var clubPageRow: String { String(localized: "clubPageRow", table: "ClubSwitch") }
        static var clubPageHint: String { String(localized: "clubPageHint", table: "ClubSwitch") }
        static func managerAdded(_ first: String, _ second: String) -> String {
            String(format: String(localized: "managerAdded", table: "ClubSwitch"), first, second)
        }
        static func managerRemoved(_ value: String) -> String {
            String(format: String(localized: "managerRemoved", table: "ClubSwitch"), value)
        }
    }
}
