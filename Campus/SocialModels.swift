import Foundation

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
    let body: String
    let isMine: Bool
    let createdAt: Date

    init(id: UUID = UUID(), author: String, body: String, isMine: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.body = body
        self.isMine = isMine
        self.createdAt = createdAt
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
    var liked: Bool
    var saved: Bool
    var isMine: Bool
    var likeCount: Int
    var comments: [SocialComment]
    let createdAt: Date

    init(id: UUID = UUID(), author: StudentProfile, caption: String, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, place: CampusPlace? = nil, liked: Bool = false, saved: Bool = false, isMine: Bool = false, likeCount: Int, comments: [SocialComment] = [], createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.caption = caption
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.localImageData = localImageData
        self.place = place
        self.liked = liked
        self.saved = saved
        self.isMine = isMine
        self.likeCount = likeCount
        self.comments = comments
        self.createdAt = createdAt
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

    /// Story'nin ekranda kalma süresi. Tek kaynak burası: paylaşırken sunucuya
    /// gönderilen bitiş zamanı da bundan hesaplanıyor.
    ///
    /// Sunucudaki `expires_at` sütununun varsayılanı hâlâ 24 saat, ama istemci
    /// değeri her zaman açıkça gönderdiği için o varsayılan hiç kullanılmıyor;
    /// süreyi değiştirmek için veritabanına dokunmak gerekmiyor.
    static let lifetime: TimeInterval = 10 * 60 * 60

    init(id: UUID = UUID(), author: StudentProfile, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, caption: String, place: CampusPlace? = nil, viewed: Bool = false, viewRecords: [StoryViewRecord] = [], isMine: Bool = false, expiresAt: Date = .now.addingTimeInterval(CampusStory.lifetime)) {
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
    }

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
    static let pinned = ["Şamdan Kafe", "İİBF", "Mühendislik Fakültesi"]

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
