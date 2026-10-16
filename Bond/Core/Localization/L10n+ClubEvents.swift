import Foundation

extension L10n {
    /// Kulüp etkinlikleri ve kulüp sayfasındaki paylaşımlar (1.1.5).
    enum ClubEvents {
        static var sectionTitle: String { String(localized: "sectionTitle", table: "ClubEvents") }
        static var add: String { String(localized: "add", table: "ClubEvents") }
        static var going: String { String(localized: "going", table: "ClubEvents") }
        static var youreGoing: String { String(localized: "youreGoing", table: "ClubEvents") }
        static var noneYet: String { String(localized: "noneYet", table: "ClubEvents") }
        static var now: String { String(localized: "now", table: "ClubEvents") }
        static var detailTitle: String { String(localized: "detailTitle", table: "ClubEvents") }
        static var attendees: String { String(localized: "attendees", table: "ClubEvents") }
        static var edit: String { String(localized: "edit", table: "ClubEvents") }
        static var cancelEvent: String { String(localized: "cancelEvent", table: "ClubEvents") }
        static var cancelBody: String { String(localized: "cancelBody", table: "ClubEvents") }
        static var keep: String { String(localized: "keep", table: "ClubEvents") }
        static var cancelled: String { String(localized: "cancelled", table: "ClubEvents") }
        static var newTitle: String { String(localized: "newTitle", table: "ClubEvents") }
        static var editTitle: String { String(localized: "editTitle", table: "ClubEvents") }
        static var titlePlaceholder: String { String(localized: "titlePlaceholder", table: "ClubEvents") }
        static var when: String { String(localized: "when", table: "ClubEvents") }
        static var place: String { String(localized: "where", table: "ClubEvents") }
        static var campusPlace: String { String(localized: "campusPlace", table: "ClubEvents") }
        static var noPlace: String { String(localized: "noPlace", table: "ClubEvents") }
        static var placeNotePlaceholder: String { String(localized: "placeNotePlaceholder", table: "ClubEvents") }
        static var details: String { String(localized: "details", table: "ClubEvents") }
        static var detailsPlaceholder: String { String(localized: "detailsPlaceholder", table: "ClubEvents") }
        static var save: String { String(localized: "save", table: "ClubEvents") }
        static var saved: String { String(localized: "saved", table: "ClubEvents") }
        static var saveFailed: String { String(localized: "saveFailed", table: "ClubEvents") }
        static var attendFailed: String { String(localized: "attendFailed", table: "ClubEvents") }
        static var reminderBodyNoPlace: String { String(localized: "reminderBodyNoPlace", table: "ClubEvents") }
        static var reminderNote: String { String(localized: "reminderNote", table: "ClubEvents") }
        static var postsTitle: String { String(localized: "postsTitle", table: "ClubEvents") }
        static var attendeesEmpty: String { String(localized: "attendeesEmpty", table: "ClubEvents") }
        static var time: String { String(localized: "time", table: "ClubEvents") }
        static var otherDate: String { String(localized: "otherDate", table: "ClubEvents") }
        static var pickDate: String { String(localized: "pickDate", table: "ClubEvents") }
        static var todayShort: String { String(localized: "todayShort", table: "ClubEvents") }
        static var timePast: String { String(localized: "timePast", table: "ClubEvents") }
        static var placeNoteExtraPlaceholder: String { String(localized: "placeNoteExtraPlaceholder", table: "ClubEvents") }
        static var create: String { String(localized: "create", table: "ClubEvents") }
        static var saveChanges: String { String(localized: "saveChanges", table: "ClubEvents") }
        static var discardTitle: String { String(localized: "discardTitle", table: "ClubEvents") }
        static var discard: String { String(localized: "discard", table: "ClubEvents") }
        static var keepEditing: String { String(localized: "keepEditing", table: "ClubEvents") }
        static var addToCalendar: String { String(localized: "addToCalendar", table: "ClubEvents") }
        static var addedToCalendar: String { String(localized: "addedToCalendar", table: "ClubEvents") }
        static var share: String { String(localized: "share", table: "ClubEvents") }
        static var about: String { String(localized: "about", table: "ClubEvents") }
        static func shareFooter(_ link: String) -> String {
            String(format: String(localized: "shareFooter", table: "ClubEvents"), link)
        }
        static func attendeeCount(_ n: Int) -> String {
            String(format: String(localized: "attendeeCount", table: "ClubEvents"), Int64(n))
        }
        static func today(_ time: String) -> String {
            String(format: String(localized: "today", table: "ClubEvents"), time)
        }
        static func tomorrow(_ time: String) -> String {
            String(format: String(localized: "tomorrow", table: "ClubEvents"), time)
        }
        static func cancelConfirm(_ title: String) -> String {
            String(format: String(localized: "cancelConfirm", table: "ClubEvents"), title)
        }
        static func reminderBody(_ place: String) -> String {
            String(format: String(localized: "reminderBody", table: "ClubEvents"), place)
        }
    }
}
