import Foundation

extension L10n {
    enum Meetings {
        static var direction: String { String(localized: "meetings.direction") }
        static var incoming: String { String(localized: "meetings.incoming") }
        static var outgoing: String { String(localized: "meetings.outgoing") }
        static var noIncoming: String { String(localized: "meetings.noIncoming") }
        static var noOutgoing: String { String(localized: "meetings.noOutgoing") }
        static var noIncomingBody: String { String(localized: "meetings.noIncomingBody") }
        static var noOutgoingBody: String { String(localized: "meetings.noOutgoingBody") }
        static var title: String { String(localized: "meetings.title") }
        static var waitingNote: String { String(localized: "meetings.waitingNote") }
        static var loadFailed: String { String(localized: "meetings.loadFailed") }
        static func sent(_ name: String, _ place: String) -> String {
            L10n.format("meetings.sent", name, place)
        }
        static var sendFailed: String { String(localized: "meetings.sendFailed") }
        static var accepted: String { String(localized: "meetings.accepted") }
        static var declined: String { String(localized: "meetings.declined") }
        static var respondFailed: String { String(localized: "meetings.respondFailed") }
    }
}
