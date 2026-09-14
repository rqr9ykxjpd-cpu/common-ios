import Foundation

/// Kampüs paylaşım tavanları. Sunucu da aynı sayıyı keser.
enum CampusLimits {
    static let maxPostsPerUser = 5
    static let maxGalleryPhotos = 5
}

struct BackendComment: Sendable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let authorName: String
    /// Yorum satırında fotoğraf yerine baş harf görünüyordu: sorgu yalnızca
    /// adı çekiyordu.
    let authorAvatarURL: URL?
    let body: String
    let createdAt: Date
    /// Cevap oyları (comment_votes). Sıralama ve "en iyi cevap" buna bakar.
    var voteCount: Int = 0
    var voted: Bool = false
    var downvoted: Bool = false
    /// Kurucunun eklediği oy; `voteCount` içinde sayılır, "geri al" için ayrı tutulur.
    var boost: Int = 0
}

/// Kurucunun kartını kaydıran (yalnızca kurucu görür).
/// Kurucunun "Veriler" ekranı: sunucudaki anlık sayılar. Sunucu jsonb
/// döndürür; eksik anahtar 0 sayılır ki yeni bir sayı eklenince eski
/// uygulama düşmesin.
struct FounderStats: Decodable, Sendable, Equatable {
    var usersTotal = 0, usersVerified = 0, usersToday = 0, usersWeek = 0
    var onlineNow = 0, activeToday = 0, activeWeek = 0, pushDevices = 0
    var plus = 0, pro = 0
    var postsTotal = 0, postsToday = 0, commentsTotal = 0, votesTotal = 0, storiesActive = 0
    var rightSwipes = 0, leftSwipes = 0, matches = 0, messagesTotal = 0
    var presentNow = 0, reportsOpen = 0

    enum CodingKeys: String, CodingKey {
        case usersTotal = "users_total", usersVerified = "users_verified"
        case usersToday = "users_today", usersWeek = "users_week"
        case activeToday = "active_today", activeWeek = "active_week"
        case onlineNow = "online_now", pushDevices = "push_devices"
        case plus, pro
        case postsTotal = "posts_total", postsToday = "posts_today"
        case commentsTotal = "comments_total", votesTotal = "votes_total", storiesActive = "stories_active"
        case rightSwipes = "right_swipes", leftSwipes = "left_swipes", matches
        case messagesTotal = "messages_total", presentNow = "present_now", reportsOpen = "reports_open"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func n(_ k: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        usersTotal = n(.usersTotal); usersVerified = n(.usersVerified)
        usersToday = n(.usersToday); usersWeek = n(.usersWeek)
        activeToday = n(.activeToday); activeWeek = n(.activeWeek)
        onlineNow = n(.onlineNow); pushDevices = n(.pushDevices)
        plus = n(.plus); pro = n(.pro)
        postsTotal = n(.postsTotal); postsToday = n(.postsToday)
        commentsTotal = n(.commentsTotal); votesTotal = n(.votesTotal); storiesActive = n(.storiesActive)
        rightSwipes = n(.rightSwipes); leftSwipes = n(.leftSwipes); matches = n(.matches)
        messagesTotal = n(.messagesTotal); presentNow = n(.presentNow); reportsOpen = n(.reportsOpen)
    }
}

struct ProfileSwiper: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let avatarURL: URL?
    /// true = sağa (bağlanmak istedi), false = sola (geçti).
    let swipedRight: Bool
    let swipedAt: Date
    let isMatched: Bool
    var avatarAssetName: String? = nil
}

/// Oy veren (yalnızca kurucu/moderatör görür).
struct PostVoter: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let avatarURL: URL?
    /// +1 / -1
    let value: Int
    /// Örnek veri için paket içi görsel.
    var avatarAssetName: String? = nil
}

struct BackendPost: Sendable {
    let id: UUID
    let authorID: UUID
    let authorName: String
    let authorBirthDate: Date
    let authorUniversity: String
    let authorDepartment: String
    let authorYear: String
    let authorBio: String
    let authorVerified: Bool
    let authorBadge: ProfileBadge
    let authorAvatarURL: URL?
    let caption: String
    let placeName: String?
    /// Gönderi türü; sunucu 'moment' varsayar.
    let kind: PostKind
    let imageData: Data?
    /// İmzalı storage URL. Profil grid'inde indirme beklemeden göstermek için.
    let imageURL: URL?
    let createdAt: Date
    let comments: [BackendComment]
    /// Net puan: yukarı oylar eksi aşağı oylar.
    let likeCount: Int
    let liked: Bool
    let downvoted: Bool
    let saved: Bool
    /// Kurucunun eklediği oy (puana dahil) ve sabitlenme zamanı.
    let boost: Int
    let pinnedAt: Date?
    /// Sabit sırası (1 = en üst); nil = sabit değil.
    let pinnedSlot: Int?

    init(
        id: UUID,
        authorID: UUID,
        authorName: String,
        authorBirthDate: Date,
        authorUniversity: String,
        authorDepartment: String,
        authorYear: String,
        authorBio: String,
        authorVerified: Bool,
        authorBadge: ProfileBadge,
        authorAvatarURL: URL?,
        caption: String,
        placeName: String?,
        kind: PostKind = .moment,
        imageData: Data?,
        imageURL: URL? = nil,
        createdAt: Date,
        comments: [BackendComment],
        likeCount: Int,
        liked: Bool,
        downvoted: Bool = false,
        saved: Bool,
        boost: Int = 0,
        pinnedAt: Date? = nil,
        pinnedSlot: Int? = nil
    ) {
        self.id = id
        self.authorID = authorID
        self.authorName = authorName
        self.authorBirthDate = authorBirthDate
        self.authorUniversity = authorUniversity
        self.authorDepartment = authorDepartment
        self.authorYear = authorYear
        self.authorBio = authorBio
        self.authorVerified = authorVerified
        self.authorBadge = authorBadge
        self.authorAvatarURL = authorAvatarURL
        self.caption = caption
        self.placeName = placeName
        self.kind = kind
        self.imageData = imageData
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.comments = comments
        self.likeCount = likeCount
        self.liked = liked
        self.downvoted = downvoted
        self.saved = saved
        self.boost = boost
        self.pinnedAt = pinnedAt
        self.pinnedSlot = pinnedSlot
    }
}

enum BackendServiceError: LocalizedError {
    case missingConfiguration
    case missingSession
    case postLimit
    case galleryFull

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            L10n.Errors.configMissing
        case .missingSession:
            L10n.Errors.missingSession
        case .postLimit:
            L10n.Composer.postLimit(CampusLimits.maxPostsPerUser)
        case .galleryFull:
            L10n.Composer.galleryFull
        }
    }
}
