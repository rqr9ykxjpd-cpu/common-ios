import Foundation

/// Kampüs paylaşım tavanları. Sunucu da aynı sayıyı keser.
enum CampusLimits {
    static let maxPostsPerUser = 5
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
    let imageData: Data?
    /// İmzalı storage URL. Profil grid'inde indirme beklemeden göstermek için.
    let imageURL: URL?
    let createdAt: Date
    let comments: [BackendComment]
    let likeCount: Int
    let liked: Bool
    let saved: Bool

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
        imageData: Data?,
        imageURL: URL? = nil,
        createdAt: Date,
        comments: [BackendComment],
        likeCount: Int,
        liked: Bool,
        saved: Bool
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
        self.imageData = imageData
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.comments = comments
        self.likeCount = likeCount
        self.liked = liked
        self.saved = saved
    }
}

enum BackendServiceError: LocalizedError {
    case missingConfiguration
    case missingSession
    case incompleteProfile
    case postLimit

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            L10n.Errors.configMissing
        case .missingSession:
            L10n.Errors.missingSession
        case .incompleteProfile:
            L10n.Errors.incompleteProfile
        case .postLimit:
            L10n.Composer.postLimit(CampusLimits.maxPostsPerUser)
        }
    }
}
