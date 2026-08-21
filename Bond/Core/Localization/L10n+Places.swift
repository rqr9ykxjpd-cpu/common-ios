import Foundation

extension L10n {
    enum Places {
        static var loadFailedTitle: String { String(localized: "places.loadFailedTitle") }
        static var loadFailedBody: String { String(localized: "places.loadFailedBody") }
        static var title: String { String(localized: "places.title") }
        static var clearFilter: String { String(localized: "places.clearFilter") }
        static func visibleAt(_ place: String) -> String {
            L10n.format("places.visibleAt", place)
        }
        static var visibleHint: String { String(localized: "places.visibleHint") }
        static var hideVisibility: String { String(localized: "places.hideVisibility") }
        static var beVisible: String { String(localized: "places.beVisible") }
        static var beVisibleHint: String { String(localized: "places.beVisibleHint") }
        static var feedFiltered: String { String(localized: "places.feedFiltered") }
        static var whoIsHere: String { String(localized: "places.whoIsHere") }
        static var imHere: String { String(localized: "places.imHere") }
        static var imHereQuestion: String { String(localized: "places.imHereQuestion") }
        static var youAreHere: String { String(localized: "places.youAreHere") }
        static var emptyHere: String { String(localized: "places.emptyHere") }
        static var emptyHereHint: String { String(localized: "places.emptyHereHint") }
        static var optionalVisibility: String { String(localized: "places.optionalVisibility") }
        static var visibleStudents: String { String(localized: "places.visibleStudents") }
        static func visibleCount(_ count: Int) -> String {
            L10n.format("places.visibleCount", Int64(count))
        }
        static var tapToHide: String { String(localized: "places.tapToHide") }
        static var makeVisible: String { String(localized: "places.makeVisible") }
        static func sendMeetupA11y(_ name: String) -> String {
            L10n.format("places.sendMeetupA11y", name)
        }
        static var hidden: String { String(localized: "places.hidden") }
        static func nowVisible(_ place: String) -> String {
            L10n.format("places.nowVisible", place)
        }
        static var toggleFailed: String { String(localized: "places.toggleFailed") }
        static var peopleFailed: String { String(localized: "places.peopleFailed") }
        static var clubsFailed: String { String(localized: "places.clubsFailed") }
        static func joinedClub(_ club: String) -> String {
            L10n.format("places.joinedClub", club)
        }
        static func leftClub(_ club: String) -> String {
            L10n.format("places.leftClub", club)
        }
        static var clubUpdateFailed: String { String(localized: "places.clubUpdateFailed") }
        static var loadFailed: String { String(localized: "places.loadFailed") }
    }
}
