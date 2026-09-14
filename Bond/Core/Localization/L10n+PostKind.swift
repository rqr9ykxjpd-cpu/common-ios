import Foundation

extension L10n {
    enum PostKind {
        static var moment: String { String(localized: "kind.moment", table: "PostKind") }
        static var question: String { String(localized: "kind.question", table: "PostKind") }
        static var announcement: String { String(localized: "kind.announcement", table: "PostKind") }
        static var notes: String { String(localized: "kind.notes", table: "PostKind") }
        /// Katalogdaki diğer rozetler: anahtar ham değerden türetilir ("kind.<raw>").
        // Dinamik anahtar: `String.LocalizationValue(_:)` anahtarı biçim dizesi
        // sayıp aramıyordu (çip "kind.help" yazdı); tabloya doğrudan bakılır.
        static func title(_ raw: String) -> String {
            Bundle.main.localizedString(forKey: "kind.\(raw)", value: nil, table: "PostKind")
        }
        static func description(_ raw: String) -> String {
            Bundle.main.localizedString(forKey: "description.\(raw)", value: nil, table: "PostKind")
        }
        static func genericPlaceholder(_ title: String) -> String {
            String(format: String(localized: "placeholder.generic", table: "PostKind"), locale: L10n.appLocale, title)
        }
        static func emptyGeneric(_ title: String) -> String {
            String(format: String(localized: "empty.generic", table: "PostKind"), locale: L10n.appLocale, title)
        }
        static var postFirst: String { String(localized: "action.postFirst", table: "PostKind") }
        /// Rozet seçmeden paylaşmaya kalkınca el yazısı uyarı.
        static var pickBadgeHint: String { String(localized: "composer.pickBadgeHint", table: "PostKind") }
        static var searchBadges: String { String(localized: "catalog.search", table: "PostKind") }

        static var questionPlaceholder: String { String(localized: "placeholder.question", table: "PostKind") }
        static var announcementPlaceholder: String { String(localized: "placeholder.announcement", table: "PostKind") }
        static var notesPlaceholder: String { String(localized: "placeholder.notes", table: "PostKind") }

        static var emptyQuestion: String { String(localized: "empty.question", table: "PostKind") }
        static var emptyAnnouncement: String { String(localized: "empty.announcement", table: "PostKind") }
        static var emptyNotes: String { String(localized: "empty.notes", table: "PostKind") }

        static var askFirst: String { String(localized: "action.askFirst", table: "PostKind") }
        static var announceFirst: String { String(localized: "action.announceFirst", table: "PostKind") }
        static var shareNotesFirst: String { String(localized: "action.shareNotesFirst", table: "PostKind") }

        /// Composer'daki rozet seçici başlığı.
        static var pickerTitle: String { String(localized: "composer.pickerTitle", table: "PostKind") }
        /// Çip sırasının sonundaki "Daha fazla…" ve açtığı katalog.
        static var moreBadges: String { String(localized: "composer.moreBadges", table: "PostKind") }
        static var catalogTitle: String { String(localized: "catalog.title", table: "PostKind") }
        static var catalogNone: String { String(localized: "catalog.none", table: "PostKind") }
        static var questionDescription: String { String(localized: "description.question", table: "PostKind") }
        static var announcementDescription: String { String(localized: "description.announcement", table: "PostKind") }
        static var notesDescription: String { String(localized: "description.notes", table: "PostKind") }
        /// Akış filtresindeki "Tümü" çipi.
        static var all: String { String(localized: "filter.all", table: "PostKind") }
        static var filterA11y: String { String(localized: "filter.a11y", table: "PostKind") }
    }
}
