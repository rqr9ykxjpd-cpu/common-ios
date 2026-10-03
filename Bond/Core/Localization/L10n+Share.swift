import Foundation

extension L10n {
    /// Uygulama dışına paylaşım.
    enum Share {
        static func postFooter(_ link: String) -> String {
            String(format: String(localized: "postFooter", table: "Share"), link)
        }
    }
}
