import Foundation

/// Kulübün etkinliği: tarih-saat, yer, kimlerin geleceği (1.1.5).
/// Sunucuda `club_events`; erişim `get_club_events` ve diğer fonksiyonlarla.
struct ClubEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let clubID: UUID
    var title: String
    var details: String
    var startsAt: Date
    var placeID: UUID?
    var placeName: String?
    var placeNote: String
    var attendeeCount: Int
    var going: Bool
    /// İlk üç katılımcının fotoğrafı (kartta üst üste).
    var attendeeAvatars: [URL]

    /// Kartta ve hatırlatmada görünen yer: kampüs noktası, yazılan yer ya da
    /// ikisi birden ("Kütüphane, 2. kat").
    var placeLabel: String? { Self.placeLabel(name: placeName, note: placeNote) }

    static func placeLabel(name: String?, note: String) -> String? {
        let parcalar = [name ?? "", note].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parcalar.isEmpty ? nil : parcalar.joined(separator: ", ")
    }

    /// Başlamış (3 saate kadar listede kalıyor, "Şimdi" diye).
    var hasStarted: Bool { startsAt <= .now }
}

/// Etkinlik aç / düzenle formunun taslağı. `id == nil` yeni etkinlik.
struct ClubEventDraft: Equatable, Sendable {
    var id: UUID?
    var clubID: UUID
    var title = ""
    var details = ""
    var startsAt: Date
    var placeID: UUID?
    var placeNote = ""

    /// Yeni etkinlik; yer olarak kulübün her zamanki buluşma noktası gelir.
    init(clubID: UUID, startsAt: Date = ClubEventDraft.defaultStart(), placeID: UUID? = nil) {
        self.clubID = clubID
        self.startsAt = startsAt
        self.placeID = placeID
    }

    init(event: ClubEvent) {
        id = event.id
        clubID = event.clubID
        title = event.title
        details = event.details
        startsAt = event.startsAt
        placeID = event.placeID
        placeNote = event.placeNote
    }

    /// Yarın 19.00: kulüp etkinliklerinin çoğu akşam.
    static func defaultStart(now: Date = .now) -> Date {
        let takvim = Calendar.current
        let yarin = takvim.date(byAdding: .day, value: 1, to: now) ?? now
        return takvim.date(bySettingHour: 19, minute: 0, second: 0, of: yarin) ?? yarin
    }
}

/// Hatırlatma için: katıldığım, henüz başlamamış etkinlik.
struct MyClubEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let clubID: UUID
    let clubName: String
    let title: String
    let startsAt: Date
    let placeLabel: String?
}
