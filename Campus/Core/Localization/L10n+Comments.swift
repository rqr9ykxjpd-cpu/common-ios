import Foundation

extension L10n {
    enum Comments {
        static var empty: String { String(localized: "comments.empty") }
        static var emptyBody: String { String(localized: "comments.emptyBody") }
        static var missingPost: String { String(localized: "comments.missingPost") }
        static var title: String { String(localized: "comments.title") }
        static var deleteConfirm: String { String(localized: "comments.deleteConfirm") }
        static var delete: String { String(localized: "comments.delete") }
        static var options: String { String(localized: "comments.options") }
        static var placeholder: String { String(localized: "comments.placeholder") }
        static var sendA11y: String { String(localized: "comments.sendA11y") }
    }
}
