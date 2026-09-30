import Foundation

extension L10n {
    /// Sorun bildir ve kurucunun Sorunlar listesi.
    enum ProblemReport {
        static var button: String { String(localized: "button", table: "ProblemReport") }
        static var title: String { String(localized: "title", table: "ProblemReport") }
        static var subtitle: String { String(localized: "subtitle", table: "ProblemReport") }
        static var placeholder: String { String(localized: "placeholder", table: "ProblemReport") }
        static var send: String { String(localized: "send", table: "ProblemReport") }
        static var sent: String { String(localized: "sent", table: "ProblemReport") }
        static var failed: String { String(localized: "failed", table: "ProblemReport") }
        static var tooShort: String { String(localized: "tooShort", table: "ProblemReport") }
        static var rateLimited: String { String(localized: "rateLimited", table: "ProblemReport") }
        static var tabReports: String { String(localized: "tabReports", table: "ProblemReport") }
        static var tabProblems: String { String(localized: "tabProblems", table: "ProblemReport") }
        static var emptyTitle: String { String(localized: "emptyTitle", table: "ProblemReport") }
        static var emptyBody: String { String(localized: "emptyBody", table: "ProblemReport") }
        static var close: String { String(localized: "close", table: "ProblemReport") }
        static var closed: String { String(localized: "closed", table: "ProblemReport") }
        static var anonymous: String { String(localized: "anonymous", table: "ProblemReport") }
        /// Öğrenci e-postası penceresinin altındaki bağlantı.
        static var eduHelp: String { String(localized: "eduHelp", table: "ProblemReport") }
        static func attached(_ info: String) -> String {
            String(format: String(localized: "attached", table: "ProblemReport"), info)
        }
        static func openCount(_ n: Int) -> String {
            String(format: String(localized: "openCount", table: "ProblemReport"), Int64(n))
        }
    }
}
