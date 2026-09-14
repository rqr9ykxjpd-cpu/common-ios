import Foundation

extension L10n {
    enum ContentReport {
        static var post: String { String(localized: "contentReport.post", table: "ContentReport") }
        static var story: String { String(localized: "contentReport.story", table: "ContentReport") }
        static var comment: String { String(localized: "contentReport.comment", table: "ContentReport") }
        static var message: String { String(localized: "contentReport.message", table: "ContentReport") }
        static var profile: String { String(localized: "contentReport.profile", table: "ContentReport") }
        static var openMedia: String { String(localized: "contentReport.openMedia", table: "ContentReport") }
        static var remove: String { String(localized: "contentReport.remove", table: "ContentReport") }
        static var removeConfirm: String { String(localized: "contentReport.removeConfirm", table: "ContentReport") }
        static var removeBody: String { String(localized: "contentReport.removeBody", table: "ContentReport") }
        static var shareMessage: String { String(localized: "contentReport.shareMessage", table: "ContentReport") }
        static var noTarget: String { String(localized: "contentReport.noTarget", table: "ContentReport") }
    }
}
