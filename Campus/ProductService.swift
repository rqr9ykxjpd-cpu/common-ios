import Foundation

struct ProfilePhotosResult: Sendable {
    let avatarURL: URL?
    let galleryURLs: [URL]
}

struct BackendNotification: Sendable {
    let id: UUID
    let kind: AppNotificationKind
    let title: String
    let body: String
    let actorID: UUID?
    let actorName: String?
    let actorAvatarURL: URL?
    let matchID: UUID?
    let isRead: Bool
    let createdAt: Date
}

struct RealtimeMessage: Sendable {
    let matchID: UUID
    let id: UUID
    let senderID: UUID
    let body: String
    let replyToID: UUID?
    let reaction: String?
    let createdAt: Date
}

enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam
    case harassment
    case impersonation
    case underage
    case other

    var id: Self { self }
    var title: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Taciz"
        case .impersonation: "Sahte hesap"
        case .underage: "Reşit değil"
        case .other: "Diğer"
        }
    }
}

protocol ProductService: Sendable {
    var isDemo: Bool { get }
    var currentUserID: UUID? { get }
    /// Oturumdaki hesabın e-postası. Uygulama silinip kurulduğunda yerel kayıt gider ama
    /// Supabase oturumu Keychain'de kaldığı için e-postayı yalnızca oturumdan geri alabiliyoruz.
    var currentUserEmail: String? { get }

    func requestOTP(email: String) async throws
    func verifyOTP(email: String, code: String) async throws
    func restoreSession() async throws -> UUID?
    func signOut() async throws
    func deleteAccount() async throws
    func saveProfile(_ draft: ProfileDraft) async throws
    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile]
    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult
    func fetchConversations() async throws -> [Conversation]
    func sendMessage(_ message: Message, matchID: UUID) async throws -> Message
    func markConversationRead(matchID: UUID) async throws
    func setMessageReaction(messageID: UUID, reaction: String?) async throws
    func fetchFeed() async throws -> [BackendPost]
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment
    func deletePost(_ postID: UUID) async throws
    func deleteComment(_ commentID: UUID) async throws
    /// Sunucudaki profil. Kullanıcının profili henüz yoksa `nil` döner — giriş akışı
    /// bu ayrımı kullanıp kullanıcıyı boş uygulamaya değil onboarding'e yönlendirir.
    func fetchMyProfile() async throws -> ProfileDraft?
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult
    func updateAvatar(_ imageData: Data?) async throws -> URL?
    func updateGallery(_ images: [Data]) async throws -> [URL]
    func blockUser(_ profileID: UUID) async throws
    func unblockUser(_ profileID: UUID) async throws
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws
    func messageStream() -> AsyncStream<RealtimeMessage>
    func setPostLiked(_ postID: UUID, liked: Bool) async throws
    func fetchNotifications() async throws -> [BackendNotification]
    func markNotificationRead(_ notificationID: UUID) async throws
    func markAllNotificationsRead() async throws
    func registerDeviceToken(_ token: String) async throws
}

struct DemoProductService: ProductService {
    let isDemo = true
    var currentUserID: UUID? { nil }
    var currentUserEmail: String? { nil }

    func requestOTP(email: String) async throws {
        try await Task.sleep(for: .milliseconds(350))
    }

    func verifyOTP(email: String, code: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func restoreSession() async throws -> UUID? { nil }
    func signOut() async throws {}
    func deleteAccount() async throws {}
    func saveProfile(_ draft: ProfileDraft) async throws {}
    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile] {
        let filtered = StudentProfile.samples.filter { profile in
            (filters.minimumAge...filters.maximumAge).contains(profile.age) &&
            (filters.academicYears.isEmpty || filters.academicYears.contains(profile.year)) &&
            (filters.departments.isEmpty || filters.departments.contains(profile.department))
        }
        return Array(filtered.dropFirst(offset).prefix(limit))
    }
    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult {
        try await Task.sleep(for: .milliseconds(180))
        let matched = liked && profileID == StudentProfile.samples[1].id
        return DiscoveryReactionResult(matched: matched, matchID: matched ? UUID() : nil)
    }
    func fetchConversations() async throws -> [Conversation] { Conversation.samples }
    func sendMessage(_ message: Message, matchID: UUID) async throws -> Message {
        try await Task.sleep(for: .milliseconds(100))
        return message
    }
    func markConversationRead(matchID: UUID) async throws {}
    func setMessageReaction(messageID: UUID, reaction: String?) async throws {}
    func fetchFeed() async throws -> [BackendPost] { [] }
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost {
        throw BackendServiceError.missingConfiguration
    }
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        throw BackendServiceError.missingConfiguration
    }
    func deletePost(_ postID: UUID) async throws {}
    func deleteComment(_ commentID: UUID) async throws {}
    func fetchMyProfile() async throws -> ProfileDraft? { nil }
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult { ProfilePhotosResult(avatarURL: nil, galleryURLs: []) }
    func updateAvatar(_ imageData: Data?) async throws -> URL? { nil }
    func updateGallery(_ images: [Data]) async throws -> [URL] { [] }
    func blockUser(_ profileID: UUID) async throws {}
    func unblockUser(_ profileID: UUID) async throws {}
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws {}
    func messageStream() -> AsyncStream<RealtimeMessage> { AsyncStream { $0.finish() } }
    func setPostLiked(_ postID: UUID, liked: Bool) async throws {}
    func fetchNotifications() async throws -> [BackendNotification] { [] }
    func markNotificationRead(_ notificationID: UUID) async throws {}
    func markAllNotificationsRead() async throws {}
    func registerDeviceToken(_ token: String) async throws {}
}

struct BackendConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var current: BackendConfiguration? {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https",
              let rawKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            return nil
        }
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return BackendConfiguration(url: url, publishableKey: key)
    }

    static var isConfigured: Bool { current != nil }
}

enum ProductServiceFactory {
    static func make() -> any ProductService {
        guard let configuration = BackendConfiguration.current else {
            return DemoProductService()
        }
        return SupabaseProductService(configuration: configuration)
    }
}
