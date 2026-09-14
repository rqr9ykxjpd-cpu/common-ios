import Foundation

extension L10n {
    enum ScreenStates {
        static var photoMissing: String { String(localized: "photoMissing", table: "ScreenStates") }
        static var photoFailed: String { String(localized: "photoFailed", table: "ScreenStates") }
        static var imageMissing: String { String(localized: "imageMissing", table: "ScreenStates") }
        static var imageFailed: String { String(localized: "imageFailed", table: "ScreenStates") }
        static var photoLoading: String { String(localized: "photoLoading", table: "ScreenStates") }
        static var imageLoading: String { String(localized: "imageLoading", table: "ScreenStates") }
        static var addPhoto: String { String(localized: "addPhoto", table: "ScreenStates") }
        static var updating: String { String(localized: "updating", table: "ScreenStates") }
        static var requests: String { String(localized: "requests", table: "ScreenStates") }
        static func unread(_ count: Int) -> String { String(format: String(localized: "unread", table: "ScreenStates"), locale: L10n.appLocale, Int64(count)) }
    }
}
