import Foundation

extension L10n {
    enum Username {
        static var title: String { String(localized: "username.title") }
        static var hint: String { String(localized: "username.hint") }
        static var checking: String { String(localized: "username.checking") }
        static var available: String { String(localized: "username.available") }
        static var taken: String { String(localized: "username.taken") }
        static var invalid: String { String(localized: "username.invalid") }
        static var checkFailed: String { String(localized: "username.checkFailed") }
        static var chooseTitle: String { String(localized: "username.chooseTitle") }
        static var chooseBody: String { String(localized: "username.chooseBody") }
        static var chooseSave: String { String(localized: "username.chooseSave") }
        static var chosen: String { String(localized: "username.chosen") }
    }
}
