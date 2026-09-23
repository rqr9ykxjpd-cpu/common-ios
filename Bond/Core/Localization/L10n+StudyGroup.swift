import Foundation

extension L10n {
    enum StudyGroup {
        static var create: String { String(localized: "studyGroup.create") }
        static var sectionTitle: String { String(localized: "studyGroup.sectionTitle") }
        static var composerTitle: String { String(localized: "studyGroup.composerTitle") }
        static var composerHint: String { String(localized: "studyGroup.composerHint") }
        static var place: String { String(localized: "studyGroup.place") }
        static var time: String { String(localized: "studyGroup.time") }
        static var now: String { String(localized: "studyGroup.now") }
        static var pickTime: String { String(localized: "studyGroup.pickTime") }
        static var notePlaceholder: String { String(localized: "studyGroup.notePlaceholder") }
        static var capacityToggle: String { String(localized: "studyGroup.capacityToggle") }
        static func capacityValue(_ n: Int) -> String { L10n.format("studyGroup.capacityValue", Int64(n)) }
        static var publish: String { String(localized: "studyGroup.publish") }
        static var join: String { String(localized: "studyGroup.join") }
        static var joined: String { String(localized: "studyGroup.joined") }
        static var full: String { String(localized: "studyGroup.full") }
        static var cancel: String { String(localized: "studyGroup.cancel") }
        static var cancelConfirm: String { String(localized: "studyGroup.cancelConfirm") }
        static var started: String { String(localized: "studyGroup.started") }
        static var today: String { String(localized: "studyGroup.today") }
        static var tomorrow: String { String(localized: "studyGroup.tomorrow") }
        static func headcount(_ n: Int) -> String { L10n.format("studyGroup.headcount", Int64(n)) }
        static func headcountOf(_ n: Int, _ cap: Int) -> String { L10n.format("studyGroup.headcountOf", Int64(n), Int64(cap)) }
        static var created: String { String(localized: "studyGroup.created") }
        static var joinedToast: String { String(localized: "studyGroup.joinedToast") }
        static var leftToast: String { String(localized: "studyGroup.leftToast") }
        static var cancelled: String { String(localized: "studyGroup.cancelled") }
        static var createFailed: String { String(localized: "studyGroup.createFailed") }
        static var joinFailed: String { String(localized: "studyGroup.joinFailed") }
        static var activeExists: String { String(localized: "studyGroup.activeExists") }
        static var closed: String { String(localized: "studyGroup.closed") }
        static var mine: String { String(localized: "studyGroup.mine") }
        static var loadFailed: String { String(localized: "studyGroup.loadFailed") }
        static var spotShow: String { String(localized: "studyGroup.spotShow") }
        static var spotRetake: String { String(localized: "studyGroup.spotRetake") }
        static var spotHint: String { String(localized: "studyGroup.spotHint") }
        static var spotBeforeWindow: String { String(localized: "studyGroup.spotBeforeWindow") }
        static var spotWaiting: String { String(localized: "studyGroup.spotWaiting") }
        static var spotMembersOnly: String { String(localized: "studyGroup.spotMembersOnly") }
        static func spotHere(_ name: String, _ time: String) -> String { L10n.format("studyGroup.spotHere", name, time) }
        static var spotShared: String { String(localized: "studyGroup.spotShared") }
        static var spotFailed: String { String(localized: "studyGroup.spotFailed") }
        static var spotWindowClosed: String { String(localized: "studyGroup.spotWindowClosed") }
        static var memberReminderTitle: String { String(localized: "studyGroup.memberReminderTitle") }
        static func memberReminderBody(_ place: String, _ host: String) -> String {
            L10n.format("studyGroup.memberReminderBody", place, host)
        }
        static var reminderTitle: String { String(localized: "studyGroup.reminderTitle") }
        static func reminderBody(_ place: String) -> String { L10n.format("studyGroup.reminderBody", place) }
        static var spotViewerTitle: String { String(localized: "studyGroup.spotViewerTitle") }
    }
}
