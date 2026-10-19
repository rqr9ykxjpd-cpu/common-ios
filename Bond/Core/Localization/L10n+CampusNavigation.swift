import Foundation

extension L10n {
    enum CampusNavigation {
        static var clubs: String { String(localized: "campus.clubs", table: "CampusNavigation") }
        static var places: String { String(localized: "campus.places", table: "CampusNavigation") }
        static var chats: String { String(localized: "campus.chats", table: "CampusNavigation") }
        static var emptyClubs: String { String(localized: "campus.emptyClubs", table: "CampusNavigation") }
        static var peopleFailed: String { String(localized: "campus.peopleFailed", table: "CampusNavigation") }
    }
}
