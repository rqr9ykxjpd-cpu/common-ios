import Foundation

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
    let createdAt: Date
    let comments: [BackendComment]
    let likeCount: Int
    let liked: Bool
    let saved: Bool
}

enum BackendServiceError: LocalizedError {
    case missingConfiguration
    case missingSession
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            L10n.Errors.configMissing
        case .missingSession:
            L10n.Errors.missingSession
        case .incompleteProfile:
            L10n.Errors.incompleteProfile
        }
    }
}
