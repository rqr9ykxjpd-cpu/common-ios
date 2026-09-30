import Foundation

/// Destek talebi: "Sorun bildir" ile başlayan küçük yazışma. Destek yanıtlar,
/// isterse "çözüldü" işaretler; öğrenci yazınca talep yeniden açılır.
struct SupportThread: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable {
        /// Öğrenci yazdı, destek henüz yanıtlamadı.
        case open
        case answered
        case resolved

        init(server: String?) { self = Status(rawValue: server ?? "") ?? .open }
    }

    let id: UUID
    /// Talebi açan ilk yazı.
    let message: String
    /// Nereden açıldı ("Profil", "Öğrenci e-postası"…).
    let screen: String?
    var status: Status
    let createdAt: Date
    var lastMessageAt: Date
    /// Destek yazdı, öğrenci henüz okumadı.
    var hasUnread: Bool
}

struct SupportMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let fromStaff: Bool
    let body: String
    let createdAt: Date
}

/// Yazışma ekranını açan bilgi; hem öğrencinin listesinden hem kurucunun
/// Sorunlar listesinden aynı ekran açılıyor.
struct SupportOpening: Identifiable, Hashable, Sendable {
    let id: UUID
    let message: String
    let createdAt: Date
    let screen: String?
    /// Kurucu tarafında kimin yazdığı ("@kullanici").
    let reporter: String?
    var status: SupportThread.Status
    /// Kurucu tarafında şikâyetçinin profil fotoğrafı.
    var reporterAvatarURL: URL? = nil
}

extension SupportThread {
    var opening: SupportOpening {
        SupportOpening(id: id, message: message, createdAt: createdAt, screen: screen, reporter: nil, status: status)
    }
}
