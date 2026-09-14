import Foundation

extension L10n {
    enum Introduction {
        static var send: String { String(localized: "send", table: "Introduction") }
        static var hint: String { String(localized: "hint", table: "Introduction") }
        static var openChat: String { String(localized: "openChat", table: "Introduction") }
        static var requests: String { String(localized: "requests", table: "Introduction") }
        static var incoming: String { String(localized: "incoming", table: "Introduction") }
        static var accepted: String { String(localized: "accepted", table: "Introduction") }
        // Kart kaydırma
        static var swipeHint: String { String(localized: "swipeHint", table: "Introduction") }
        static var swipeHintLeft: String { String(localized: "swipeHintLeft", table: "Introduction") }
        static var swipeHintRight: String { String(localized: "swipeHintRight", table: "Introduction") }
        static var connect: String { String(localized: "connect", table: "Introduction") }
        static var close: String { String(localized: "close", table: "Introduction") }
        static var connected: String { String(localized: "connected", table: "Introduction") }
        static var connectedBody: String { String(localized: "connectedBody", table: "Introduction") }
    }
}
