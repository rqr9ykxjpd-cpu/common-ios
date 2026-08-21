import Foundation

extension L10n {
    enum Report {
        static var spam: String { String(localized: "report.spam") }
        static var harassment: String { String(localized: "report.harassment") }
        static var impersonation: String { String(localized: "report.impersonation") }
        static var underage: String { String(localized: "report.underage") }
        static var other: String { String(localized: "report.other") }
    }
}
