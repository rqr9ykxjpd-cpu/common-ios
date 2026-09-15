import Foundation

extension L10n {
    enum StudyGroup {
        static var create: String { String(localized: "studyGroup.create") }
        static var sectionTitle: String { String(localized: "studyGroup.sectionTitle") }
        static var composerTitle: String { String(localized: "studyGroup.composerTitle") }
        static var composerHint: String { String(localized: "studyGroup.composerHint") }
        static var place: String { String(localized: "studyGroup.place") }
        static var time: String { String(localized: "studyGroup.time") }
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
    }
}
