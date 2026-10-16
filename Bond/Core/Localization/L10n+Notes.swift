import Foundation

extension L10n {
    /// Ders notları (1.1.6): Kim nerede → Notlar.
    enum Notes {
        static var title: String { String(localized: "title", table: "Notes") }
        static var entrySubtitle: String { String(localized: "entrySubtitle", table: "Notes") }
        static var share: String { String(localized: "share", table: "Notes") }
        static var shared: String { String(localized: "shared", table: "Notes") }
        static var shareFailed: String { String(localized: "shareFailed", table: "Notes") }
        static var loadFailed: String { String(localized: "loadFailed", table: "Notes") }
        static var noNotesYet: String { String(localized: "noNotesYet", table: "Notes") }
        static var departmentEmpty: String { String(localized: "departmentEmpty", table: "Notes") }
        static var yourDepartment: String { String(localized: "yourDepartment", table: "Notes") }
        static var departments: String { String(localized: "departments", table: "Notes") }
        static var captionPlaceholder: String { String(localized: "captionPlaceholder", table: "Notes") }
        static var department: String { String(localized: "department", table: "Notes") }
        static var departmentPlaceholder: String { String(localized: "departmentPlaceholder", table: "Notes") }
        static var pages: String { String(localized: "pages", table: "Notes") }
        static var addPages: String { String(localized: "addPages", table: "Notes") }
        static var pagesHint: String { String(localized: "pagesHint", table: "Notes") }
        static var copyright: String { String(localized: "copyright", table: "Notes") }
        static var publish: String { String(localized: "publish", table: "Notes") }
        static var discardTitle: String { String(localized: "discardTitle", table: "Notes") }
        static func noteCount(_ n: Int) -> String {
            String(format: String(localized: "noteCount", table: "Notes"), Int64(n))
        }
    }
}
