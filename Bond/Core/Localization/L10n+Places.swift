import Foundation

extension L10n {
    enum Places {
        static func peopleHere(_ count: Int) -> String { L10n.format("places.peopleHere", Int64(count)) }
        static var nobodyHere: String { String(localized: "places.nobodyHere") }
        static var loadFailedTitle: String { String(localized: "places.loadFailedTitle") }
        static var emptyTitle: String { String(localized: "places.emptyTitle") }
        static var emptyBody: String { String(localized: "places.emptyBody") }
        static var title: String { String(localized: "places.title") }
        static var clearFilter: String { String(localized: "places.clearFilter") }
        static func visibleAt(_ place: String) -> String {
            L10n.format("places.visibleAt", place)
        }
        static var hideVisibility: String { String(localized: "places.hideVisibility") }
        static var notVisible: String { String(localized: "places.notVisible") }
        static var beVisibleHint: String { String(localized: "places.beVisibleHint") }
        static var feedFiltered: String { String(localized: "places.feedFiltered") }
        static var whoIsHere: String { String(localized: "places.whoIsHere") }
        static var imHere: String { String(localized: "places.imHere") }
        static var youAreHere: String { String(localized: "places.youAreHere") }
        static var emptyHere: String { String(localized: "places.emptyHere") }
        static var emptyHereHint: String { String(localized: "places.emptyHereHint") }
        static func sendMeetupA11y(_ name: String) -> String {
            L10n.format("places.sendMeetupA11y", name)
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
