import Foundation

extension L10n {
    /// Okul e-postası kodla doğrulama (1.1.1).
    enum EduCode {
        static var sentTitle: String { String(localized: "sentTitle", table: "EduCode") }
        static func sentBody(_ email: String) -> String {
            String(format: String(localized: "sentBody", table: "EduCode"), email)
        }
        static var placeholder: String { String(localized: "placeholder", table: "EduCode") }
        static var verify: String { String(localized: "verify", table: "EduCode") }
        static var invalid: String { String(localized: "invalid", table: "EduCode") }
        static var linkFallback: String { String(localized: "linkFallback", table: "EduCode") }
        static var sendCode: String { String(localized: "sendCode", table: "EduCode") }
        static var sheetHint: String { String(localized: "sheetHint", table: "EduCode") }
        static var tooManyTries: String { String(localized: "tooManyTries", table: "EduCode") }
    }
}
