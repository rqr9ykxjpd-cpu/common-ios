import Foundation

extension L10n {
    /// Çoklu fotoğraflı gönderi.
    enum PostPhotos {
        static var add: String { String(localized: "add", table: "PostPhotos") }
        static var remove: String { String(localized: "remove", table: "PostPhotos") }
        static func count(_ current: Int, of total: Int) -> String {
            String(format: String(localized: "count", table: "PostPhotos"), Int64(current), Int64(total))
        }
        static func footer(_ limit: Int) -> String {
            String(format: String(localized: "footer", table: "PostPhotos"), Int64(limit))
        }
    }
}
