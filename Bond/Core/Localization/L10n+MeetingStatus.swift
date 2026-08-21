import Foundation

extension L10n {
    enum MeetingStatus {
        static var pending: String { String(localized: "meetingStatus.pending") }
        static var accepted: String { String(localized: "meetingStatus.accepted") }
        static var declined: String { String(localized: "meetingStatus.declined") }
    }
}
