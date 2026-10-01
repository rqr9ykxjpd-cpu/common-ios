import Foundation

/// Kulüp listesine sonradan eklenen bilgiler (1.2): logo ve iletişim. Ayrı
/// çekiliyor; eski sürümlerin kulüp sorgusu değişmesin.
struct ClubExtras: Equatable, Sendable {
    var logoURL: URL?
    var instagram: String?
    var contactEmail: String?
}

/// Düzenleme ekranının taslağı. `id == nil` yeni kulüp (yalnızca kurucu).
struct ClubDraft: Equatable, Sendable {
    var id: UUID?
    var name = ""
    var summary = ""
    var icon = "person.3.fill"
    var nextEvent = ""
    var placeID: UUID?
    var accentHex = "7C5CFF"
    var instagram = ""
    var contactEmail = ""
    var isActive = true
    var logoURL: URL?
}

/// Kurucu listesindeki satır: kapalı kulüpler dahil.
struct ClubAdminEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    var draft: ClubDraft
    let memberCount: Int
    let managerCount: Int
}

/// Kulübün üyesi ya da yöneticisi (yönetici ve kurucu görür).
struct ClubPerson: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let username: String?
    let avatarURL: URL?
    var isManager: Bool
    let joinedAt: Date
}

/// Kulüp ekranlarında seçilebilen simgeler ve renkler: sade, uygulamanın diliyle.
enum ClubPalette {
    static let icons = [
        "person.3.fill", "camera.fill", "music.note", "leaf.fill", "book.fill",
        "theatermasks.fill", "sportscourt.fill", "globe.europe.africa.fill",
        "cpu.fill", "paintpalette.fill", "heart.fill", "film.fill",
        "gamecontroller.fill", "flask.fill", "mic.fill", "figure.run"
    ]
    static let colors = ["7C5CFF", "E8692C", "2F8F5B", "2D6CDF", "C2410C", "B4235A", "0F766E", "6B7280"]
}
