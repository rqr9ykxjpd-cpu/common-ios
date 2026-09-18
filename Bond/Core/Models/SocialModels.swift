import Foundation

/// Bir yerde şu an kaç kişi görünüyor + ilk birkaç avatar (liste satırı için).
struct PlacePresenceSummary: Hashable, Sendable {
    let placeID: UUID
    let count: Int
    let avatarURLs: [URL]
    var avatarAssetNames: [String] = []
}

/// Çalışma grubu: "şu saatte şurada ders çalışacağım". Kim nerede'deki
/// BURADAYIM gibi tek dokunuşla katılınır; grup sohbeti yok, tanışma kartlardan.
struct StudyGroup: Identifiable, Hashable {
    let id: UUID
    let host: StudentProfile
    let place: CampusPlace
    let startsAt: Date
    let note: String
    /// nil: sınırsız. Ev sahibi dâhil toplam kişi.
    let capacity: Int?
    var members: [StudentProfile]
    let createdAt: Date
    var isMine: Bool
    var joined: Bool
    /// "Yerimi göster" fotoğrafı: yalnızca katılanlar ve ev sahibi imzalı URL alır.
    /// Fotoğraf var ama URL yoksa (katılmayan) kartta "katılanlara açık" yazar.
    var spotPhotoURL: URL?
    var spotPhotoAt: Date?

    /// Ev sahibi + katılanlar.
    var headcount: Int { members.count + 1 }
    var isFull: Bool { capacity.map { headcount >= $0 } ?? false }
    var hasStarted: Bool { startsAt <= .now }
    /// Fotoğraf penceresi: başlangıçtan 15 dk önce → bitişe kadar.
    var spotWindowOpen: Bool {
        let now = Date()
        return now >= startsAt.addingTimeInterval(-15 * 60) && now < startsAt.addingTimeInterval(2 * 3600)
    }
    var hasSpotPhoto: Bool { spotPhotoAt != nil }
}

struct CampusPlace: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let area: String

    init(id: UUID = UUID(), name: String, area: String) {
        self.id = id
        self.name = name
        self.area = area
    }

}

extension StudentProfile {
}

extension CampusPlace {
}

struct CampusClub: Identifiable, Hashable {
    let id: UUID
    let name: String
    let summary: String
    let icon: String
    let memberCount: Int
    let nextEvent: String
    let meetingPlace: CampusPlace?
    let accentHex: String

    init(id: UUID = UUID(), name: String, summary: String, icon: String, memberCount: Int, nextEvent: String, meetingPlace: CampusPlace?, accentHex: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.icon = icon
        self.memberCount = memberCount
        self.nextEvent = nextEvent
        self.meetingPlace = meetingPlace
        self.accentHex = accentHex
    }

}

struct SocialComment: Identifiable, Hashable {
    let id: UUID
    let author: String
    let authorAvatarURL: URL?
    let body: String
    let isMine: Bool
    let createdAt: Date
    var voteCount: Int
    var voted: Bool
    var downvoted: Bool
    /// Kurucunun eklediği oy (voteCount'a dahil).
    var boost: Int

    init(id: UUID = UUID(), author: String, authorAvatarURL: URL? = nil, body: String, isMine: Bool = false, createdAt: Date = .now, voteCount: Int = 0, voted: Bool = false, downvoted: Bool = false, boost: Int = 0) {
        self.id = id
        self.author = author
        self.authorAvatarURL = authorAvatarURL
        self.body = body
        self.isMine = isMine
        self.createdAt = createdAt
        self.voteCount = voteCount
        self.voted = voted
        self.downvoted = downvoted
        self.boost = boost
    }
}

struct SocialPost: Identifiable, Hashable {
    let id: UUID
    let author: StudentProfile
    var caption: String
    var imageURL: URL?
    var imageAssetName: String?
    var localImageData: Data?
    var place: CampusPlace?
    var kind: PostKind
    var liked: Bool
    var downvoted: Bool
    var saved: Bool
    var isMine: Bool
    /// Kurucu oyu (likeCount'a dahil) ve sabit.
    var boost: Int
    var pinnedAt: Date?
    var pinnedSlot: Int?
    var likeCount: Int
    var comments: [SocialComment]
    let createdAt: Date

    init(id: UUID = UUID(), author: StudentProfile, caption: String, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, place: CampusPlace? = nil, kind: PostKind = .moment, liked: Bool = false, downvoted: Bool = false, saved: Bool = false, isMine: Bool = false, likeCount: Int, comments: [SocialComment] = [], createdAt: Date = .now, boost: Int = 0, pinnedAt: Date? = nil, pinnedSlot: Int? = nil) {
        self.id = id
        self.author = author
        self.caption = caption
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.localImageData = localImageData
        self.place = place
        self.kind = kind
        self.liked = liked
        self.downvoted = downvoted
        self.saved = saved
        self.isMine = isMine
        self.likeCount = likeCount
        self.comments = comments
        self.createdAt = createdAt
        self.boost = boost
        self.pinnedAt = pinnedAt
        self.pinnedSlot = pinnedSlot
    }

    var hasPhoto: Bool {
        imageURL != nil || imageAssetName != nil || localImageData != nil
    }
}

struct StoryViewRecord: Identifiable, Hashable {
    let id: UUID
    let viewer: StudentProfile
    var viewCount: Int
    var lastViewedAt: Date

    init(id: UUID = UUID(), viewer: StudentProfile, viewCount: Int, lastViewedAt: Date = .now) {
        self.id = id
        self.viewer = viewer
        self.viewCount = viewCount
        self.lastViewedAt = lastViewedAt
    }
}

struct CampusStory: Identifiable, Hashable {
    let id: UUID
    let author: StudentProfile
    let imageURL: URL?
    let imageAssetName: String?
    let localImageData: Data?
    let caption: String
    let place: CampusPlace?
    var viewed: Bool
    var viewRecords: [StoryViewRecord]
    var isMine: Bool
    let expiresAt: Date
    /// Varsayılan fotoğraf: kolon yoksa veya eski satır.
    let mediaKind: StoryMediaKind
    /// Yalnızca video. İmzalı MP4 adresi.
    let videoURL: URL?
    /// Video kapağı; fotoğrafta `imageURL` kullanılır.
    let posterURL: URL?
    /// Video süresi (saniye). Fotoğrafta nil.
    let duration: TimeInterval?

    var isVideo: Bool { mediaKind == .video }

    /// Story'nin ekranda kalma süresi. Tek kaynak burası: paylaşırken sunucuya
    /// gönderilen bitiş zamanı da bundan hesaplanıyor.
    ///
    /// Sunucudaki `expires_at` sütununun varsayılanı hâlâ 24 saat, ama istemci
    /// değeri her zaman açıkça gönderdiği için o varsayılan hiç kullanılmıyor;
    /// süreyi değiştirmek için veritabanına dokunmak gerekmiyor.
    static let lifetime: TimeInterval = 10 * 60 * 60
    /// Fotoğraf story'nin ekranda kalış süresi (oynatıcı).
    static let photoPlayback: TimeInterval = 6
    /// Sunucunun kabul ettiği üst sınır; sıkıştırma da bunu keser.
    static let maxVideoDuration: TimeInterval = 15

    init(id: UUID = UUID(), author: StudentProfile, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, caption: String, place: CampusPlace? = nil, viewed: Bool = false, viewRecords: [StoryViewRecord] = [], isMine: Bool = false, expiresAt: Date = .now.addingTimeInterval(CampusStory.lifetime), mediaKind: StoryMediaKind = .image, videoURL: URL? = nil, posterURL: URL? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.author = author
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.localImageData = localImageData
        self.caption = caption
        self.place = place
        self.viewed = viewed
        self.viewRecords = viewRecords
        self.isMine = isMine
        self.expiresAt = expiresAt
        self.mediaKind = mediaKind
        self.videoURL = videoURL
        self.posterURL = posterURL
        self.duration = duration
    }

    func replacingAuthor(_ author: StudentProfile) -> CampusStory {
        CampusStory(
            id: id, author: author, imageURL: imageURL, imageAssetName: imageAssetName,
            localImageData: localImageData, caption: caption, place: place, viewed: viewed,
            viewRecords: viewRecords, isMine: isMine, expiresAt: expiresAt, mediaKind: mediaKind,
            videoURL: videoURL, posterURL: posterURL, duration: duration
        )
    }
}

enum StoryMediaKind: String, Hashable, Sendable {
    case image
    case video
}

/// Story paylaşımının iki yolu. Gönderi (post) hâlâ yalnızca fotoğraf.
enum StoryUpload: Sendable {
    case photo(Data)
    case video(fileURL: URL, posterJPEG: Data, duration: TimeInterval)
}


/// Profilini görüntüleyen biri. Kayıt sunucuda tutuluyor ve yalnızca profil
/// sahibi görebiliyor; 30 günden eski ziyaretler listelenmez.
struct ProfileVisit: Identifiable, Hashable {
    let id: UUID
    let profile: StudentProfile
    let visitedAt: Date

    init(profile: StudentProfile, visitedAt: Date) {
        self.id = profile.id
        self.profile = profile
        self.visitedAt = visitedAt
    }
}

/// Yerlerin gösterim sırası.
///
/// Alfabetik sıra en çok kullanılan noktaları listenin ortasına gömüyordu; akıştaki
/// şeritte yalnızca ilk birkaçı görünüyor ve oraya "Aytaç Cafe", "Hukuk Fakültesi"
/// gibi rastgele düşen isimler geliyordu. Kampüste en çok buluşulan yerler başta.
enum CampusPlaceOrder {
    /// Başa alınacaklar, bu sırayla.
    ///
    /// Öncelik kampüsteki buluşma noktaları: insanlar fakülte binasında değil
    /// kafede oturuyor. Fakülteler listede kalıyor, sadece arkaya düşüyor.
    static let pinned = [
        "Şamdan Kafe", "Aytaç Cafe", "Hazırlık Kantini", "Otağ",
        "Yemekhane", "Merkez Kütüphane"
    ]

    static func sorted(_ places: [CampusPlace]) -> [CampusPlace] {
        places.sorted { first, second in
            let firstIndex = pinned.firstIndex(of: first.name)
            let secondIndex = pinned.firstIndex(of: second.name)
            switch (firstIndex, secondIndex) {
            case let (a?, b?): return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            }
        }
    }
}
