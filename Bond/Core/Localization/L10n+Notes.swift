import Foundation

extension L10n {
    /// Ders notları (1.1.7): Kim nerede → Notlar.
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
        static var department: String { String(localized: "department", table: "Notes") }
        static var departmentPlaceholder: String { String(localized: "departmentPlaceholder", table: "Notes") }
        static var pages: String { String(localized: "pages", table: "Notes") }
        static var addPages: String { String(localized: "addPages", table: "Notes") }
        static var copyright: String { String(localized: "copyright", table: "Notes") }
        static var publish: String { String(localized: "publish", table: "Notes") }
        static var discardTitle: String { String(localized: "discardTitle", table: "Notes") }
        static var openFailed: String { String(localized: "openFailed", table: "Notes") }
        static var saveFile: String { String(localized: "saveFile", table: "Notes") }
        static var open: String { String(localized: "open", table: "Notes") }
        static var searchPrompt: String { String(localized: "searchPrompt", table: "Notes") }
        static var searchEmpty: String { String(localized: "searchEmpty", table: "Notes") }
        static var fromYourDepartment: String { String(localized: "fromYourDepartment", table: "Notes") }
        static var seeAll: String { String(localized: "seeAll", table: "Notes") }
        static var allCourses: String { String(localized: "allCourses", table: "Notes") }
        static var sort: String { String(localized: "sort", table: "Notes") }
        static var sortNewest: String { String(localized: "sortNewest", table: "Notes") }
        static var sortTop: String { String(localized: "sortTop", table: "Notes") }
        static var sourceScan: String { String(localized: "sourceScan", table: "Notes") }
        static var sourcePhotos: String { String(localized: "sourcePhotos", table: "Notes") }
        static var sourcePDF: String { String(localized: "sourcePDF", table: "Notes") }
        static var sourcesHint: String { String(localized: "sourcesHint", table: "Notes") }
        static var reorderHint: String { String(localized: "reorderHint", table: "Notes") }
        static var course: String { String(localized: "course", table: "Notes") }
        static var coursePlaceholder: String { String(localized: "coursePlaceholder", table: "Notes") }
        static var topic: String { String(localized: "topic", table: "Notes") }
        static var topicPlaceholder: String { String(localized: "topicPlaceholder", table: "Notes") }
        static var moveEarlier: String { String(localized: "moveEarlier", table: "Notes") }
        static var moveLater: String { String(localized: "moveLater", table: "Notes") }
        static var removeFile: String { String(localized: "removeFile", table: "Notes") }
        static var delete: String { String(localized: "delete", table: "Notes") }
        static var deleteConfirm: String { String(localized: "deleteConfirm", table: "Notes") }
        static var pageLimit: String { String(localized: "pageLimit", table: "Notes") }
        static var pdfTooLarge: String { String(localized: "pdfTooLarge", table: "Notes") }
        static var pdfUnreadable: String { String(localized: "pdfUnreadable", table: "Notes") }
        static var pdfLocked: String { String(localized: "pdfLocked", table: "Notes") }
        static var pdfTooManyPages: String { String(localized: "pdfTooManyPages", table: "Notes") }
        static func pageCount(_ n: Int) -> String {
            String(format: String(localized: "pageCount", table: "Notes"), Int64(n))
        }
        static func pageOf(_ page: Int, _ total: Int) -> String {
            String(format: String(localized: "pageOf", table: "Notes"), Int64(page), Int64(total))
        }
        static func noteCount(_ n: Int) -> String {
            String(format: String(localized: "noteCount", table: "Notes"), Int64(n))
        }
    }
}
