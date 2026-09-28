import Foundation

extension L10n {
    /// Kartını düzenle: profil kartının rengi.
    enum CardStudio {
        static var editCard: String { String(localized: "editCard", table: "CardStudio") }
        // Yalnız karta fotoğraf (CardPhotoComposer)
        static var photoMenu: String { String(localized: "photoMenu", table: "CardStudio") }
        static var photoTitle: String { String(localized: "photoTitle", table: "CardStudio") }
        static var photoNote: String { String(localized: "photoNote", table: "CardStudio") }
        static var photoPick: String { String(localized: "photoPick", table: "CardStudio") }
        static var photoChange: String { String(localized: "photoChange", table: "CardStudio") }
        static var photoAdd: String { String(localized: "photoAdd", table: "CardStudio") }
        static var photoAdded: String { String(localized: "photoAdded", table: "CardStudio") }
        static var photoAddShort: String { String(localized: "photoAddShort", table: "CardStudio") }
        static func photoCount(_ count: Int, _ limit: Int) -> String {
            String(format: String(localized: "photoCount", table: "CardStudio"), locale: L10n.appLocale, Int64(count), Int64(limit))
        }
        static var title: String { String(localized: "title", table: "CardStudio") }
        static var subtitle: String { String(localized: "subtitle", table: "CardStudio") }
        static var save: String { String(localized: "save", table: "CardStudio") }
        static var saved: String { String(localized: "saved", table: "CardStudio") }
        static var failed: String { String(localized: "failed", table: "CardStudio") }
        static var classic: String { String(localized: "classic", table: "CardStudio") }
        static var ink: String { String(localized: "ink", table: "CardStudio") }
        static var navy: String { String(localized: "navy", table: "CardStudio") }
        static var terracotta: String { String(localized: "terracotta", table: "CardStudio") }
        static var sage: String { String(localized: "sage", table: "CardStudio") }
        static var lavender: String { String(localized: "lavender", table: "CardStudio") }
        static var rose: String { String(localized: "rose", table: "CardStudio") }
        static var ocean: String { String(localized: "ocean", table: "CardStudio") }
        static var editProfile: String { String(localized: "editProfile", table: "CardStudio") }
        static var member: String { String(localized: "member", table: "CardStudio") }
        static var department: String { String(localized: "department", table: "CardStudio") }
        static var visibleNote: String { String(localized: "visibleNote", table: "CardStudio") }
        static var raspberry: String { String(localized: "raspberry", table: "CardStudio") }
        static var bubblegum: String { String(localized: "bubblegum", table: "CardStudio") }
    }
}
