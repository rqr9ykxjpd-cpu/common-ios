import Foundation

extension L10n {
    /// Kulüp yönetimi (1.2).
    enum ClubAdmin {
        static var clubsTitle: String { String(localized: "clubsTitle", table: "ClubAdmin") }
        static var clubsHint: String { String(localized: "clubsHint", table: "ClubAdmin") }
        static var newClub: String { String(localized: "newClub", table: "ClubAdmin") }
        static var editClub: String { String(localized: "editClub", table: "ClubAdmin") }
        static var edit: String { String(localized: "edit", table: "ClubAdmin") }
        static var save: String { String(localized: "save", table: "ClubAdmin") }
        static var name: String { String(localized: "name", table: "ClubAdmin") }
        static var namePlaceholder: String { String(localized: "namePlaceholder", table: "ClubAdmin") }
        static var summary: String { String(localized: "summary", table: "ClubAdmin") }
        static var summaryPlaceholder: String { String(localized: "summaryPlaceholder", table: "ClubAdmin") }
        static var nextEvent: String { String(localized: "nextEvent", table: "ClubAdmin") }
        static var nextEventPlaceholder: String { String(localized: "nextEventPlaceholder", table: "ClubAdmin") }
        static var place: String { String(localized: "place", table: "ClubAdmin") }
        static var noPlace: String { String(localized: "noPlace", table: "ClubAdmin") }
        static var logo: String { String(localized: "logo", table: "ClubAdmin") }
        static var logoPick: String { String(localized: "logoPick", table: "ClubAdmin") }
        static var logoChange: String { String(localized: "logoChange", table: "ClubAdmin") }
        static var logoAfterSave: String { String(localized: "logoAfterSave", table: "ClubAdmin") }
        static var look: String { String(localized: "look", table: "ClubAdmin") }
        static var icon: String { String(localized: "icon", table: "ClubAdmin") }
        static var color: String { String(localized: "color", table: "ClubAdmin") }
        static var contact: String { String(localized: "contact", table: "ClubAdmin") }
        static var instagramPlaceholder: String { String(localized: "instagramPlaceholder", table: "ClubAdmin") }
        static var emailPlaceholder: String { String(localized: "emailPlaceholder", table: "ClubAdmin") }
        static var active: String { String(localized: "active", table: "ClubAdmin") }
        static var activeHint: String { String(localized: "activeHint", table: "ClubAdmin") }
        static var managers: String { String(localized: "managers", table: "ClubAdmin") }
        static var managersHint: String { String(localized: "managersHint", table: "ClubAdmin") }
        static var addManager: String { String(localized: "addManager", table: "ClubAdmin") }
        static var removeManager: String { String(localized: "removeManager", table: "ClubAdmin") }
        static var managerSearch: String { String(localized: "managerSearch", table: "ClubAdmin") }
        static var managerChip: String { String(localized: "managerChip", table: "ClubAdmin") }
        static var members: String { String(localized: "members", table: "ClubAdmin") }
        static var removeMember: String { String(localized: "removeMember", table: "ClubAdmin") }
        static var membersEmpty: String { String(localized: "membersEmpty", table: "ClubAdmin") }
        static var inactive: String { String(localized: "inactive", table: "ClubAdmin") }
        static var saved: String { String(localized: "saved", table: "ClubAdmin") }
        static var saveFailed: String { String(localized: "saveFailed", table: "ClubAdmin") }
        static var nameRequired: String { String(localized: "nameRequired", table: "ClubAdmin") }
        static var emptyClubs: String { String(localized: "emptyClubs", table: "ClubAdmin") }
        static var emptyClubsBody: String { String(localized: "emptyClubsBody", table: "ClubAdmin") }
        static var managerNote: String { String(localized: "managerNote", table: "ClubAdmin") }
        static var openInstagram: String { String(localized: "openInstagram", table: "ClubAdmin") }
        static var sendEmail: String { String(localized: "sendEmail", table: "ClubAdmin") }
        static var loadFailed: String { String(localized: "loadFailed", table: "ClubAdmin") }
        static var instagramInvalid: String { String(localized: "instagramInvalid", table: "ClubAdmin") }
        static var emailInvalid: String { String(localized: "emailInvalid", table: "ClubAdmin") }
        static func memberCount(_ n: Int) -> String {
            String(format: String(localized: "memberCount", table: "ClubAdmin"), Int64(n))
        }
        static func managerCount(_ n: Int) -> String {
            String(format: String(localized: "managerCount", table: "ClubAdmin"), Int64(n))
        }
        static func removeMemberConfirm(_ name: String) -> String {
            String(format: String(localized: "removeMemberConfirm", table: "ClubAdmin"), name)
        }
        static var removeMemberHint: String { String(localized: "removeMemberHint", table: "ClubAdmin") }
    }
}
