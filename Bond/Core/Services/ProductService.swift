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
        case .spam: L10n.Report.spam
        case .harassment: L10n.Report.harassment
        case .impersonation: L10n.Report.impersonation
        case .underage: L10n.Report.underage
        case .other: L10n.Report.other
        }
    }
}

protocol ProductService: Sendable {
    var currentUserID: UUID? { get }
    /// Oturumdaki hesabın e-postası. Uygulama silinip kurulduğunda yerel kayıt gider ama
    /// Supabase oturumu Keychain'de kaldığı için e-postayı yalnızca oturumdan geri alabiliyoruz.
    var currentUserEmail: String? { get }

    func signInWithApple(idToken: String, nonce: String) async throws
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async throws
    /// E-posta adresine giriş bağlantısı gönderir.
    func requestEmailSignInLink(email: String) async throws
    /// Kullanıcı maildeki bağlantıya dokununca iOS'un uygulamaya ilettiği URL.
    /// İçindeki token'ı doğrulayıp oturumu kurar.
    func completeEmailSignIn(url: URL) async throws
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

    /// Kendi mesajını siler. Sunucu yalnızca gönderenin kendi mesajına izin veriyor.
    func deleteMessage(_ messageID: UUID) async throws
    /// Kendi mesajının metnini değiştirir.
    func editMessage(_ messageID: UUID, body: String) async throws

    /// Story beğenisi. `liked` false ise beğeni kaldırılır.
    func setStoryLiked(_ storyID: UUID, liked: Bool) async throws
    /// Bu story'yi beğenmiş miyim.
    func isStoryLiked(_ storyID: UUID) async throws -> Bool
    func fetchFeed() async throws -> [BackendPost]
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment
    func deletePost(_ postID: UUID) async throws
    func deleteComment(_ commentID: UUID) async throws
    /// Sunucudaki profil. Kullanıcının profili henüz yoksa `nil` döner — giriş akışı
    /// bu ayrımı kullanıp kullanıcıyı boş uygulamaya değil onboarding'e yönlendirir.
    func fetchMyProfile() async throws -> ProfileDraft?
    /// Apple'ın imzaladığı satın alma belgesini sunucuya iletir. Sunucu belgeyi
    /// Apple'a doğrulatıp kademeyi kendisi yazıyor; istemcinin "ben Pro oldum"
    /// demesi tek başına hiçbir şey değiştirmiyor.
    func submitPurchase(jws: String, productID: String) async throws
    /// Sunucunun bildiği kademe. Sınırları uygulayan kayıt bu; cihazın bildiğiyle
    /// ayrışırsa doğru olan budur.
    func fetchMyPlan() async throws -> SubscriptionTier
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult
    func updateAvatar(_ imageData: Data?) async throws -> URL?
    func updateGallery(_ images: [Data]) async throws -> [URL]
    func blockUser(_ profileID: UUID) async throws
    func unblockUser(_ profileID: UUID) async throws
    /// Engellediğin kişiler. Engeli kaldırabilmek için önce kimi engellediğini
    /// görebilmen gerekiyor; engelleme tek yönlü bir kapı olmamalı.
    func fetchBlockedProfiles() async throws -> [BlockedProfile]
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws
    /// Şikayet listesi. Yalnızca moderatör okuyabiliyor; başkası çağırırsa boş döner.
    func fetchReports() async throws -> [ModerationReport]
    /// Kurucuya özel: hesabımı sağa kaydıranlar. Yetkiyi sunucu denetliyor.
    func fetchAdmirers() async throws -> [Admirer]
    /// Şikayeti kapatır.
    func resolveReport(_ reportID: UUID, resolution: String) async throws
    /// Moderatör olarak içerik kaldırır.
    func moderatorDeletePost(_ postID: UUID) async throws
    /// Hesabı askıya alır ya da geri açar.
    func setAccountActive(_ profileID: UUID, active: Bool) async throws
    func messageStream() -> AsyncStream<RealtimeMessage>
    func setPostLiked(_ postID: UUID, liked: Bool) async throws
    func setPostSaved(_ postID: UUID, saved: Bool) async throws
    /// Kaydedilen gönderiler. Akıştan süzmek yetmiyor: akış yalnızca son 100 gönderiyi
    /// getirdiği için eski bir gönderiyi kaydeden kişi onu yer imlerinde bulamıyordu.
    func fetchSavedPosts() async throws -> [BackendPost]
    /// Bir kişinin ilgi alanları ve galeri fotoğrafları. Gönderi ve story
    /// sorguları yazar için yalnızca temel alanları getiriyor; kişinin profiline
    /// girildiğinde kart bu yüzden bomboş görünüyordu.
    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails

    /// "Geç" kararlarını siler; o kişiler keşifte tekrar görünür hale gelir.
    /// Beğenilere dokunmaz, dolayısıyla eşleşmeler etkilenmez.
    func resetPasses() async throws
    func fetchNotifications() async throws -> [BackendNotification]
    func markNotificationRead(_ notificationID: UUID) async throws
    func markAllNotificationsRead() async throws
    func registerDeviceToken(_ token: String) async throws
    func fetchPlaces() async throws -> [CampusPlace]
    func fetchMeetingRequests() async throws -> [MeetingRequest]
    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws
    /// Kabul edilirse oluşturulan/yeniden açılan sohbetin kimliğini döner.
    /// Reddetme işleminde eşleşme oluşmadığı için `nil` döner.
    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws -> UUID?
    /// Eşleşmeden yanıt. Sohbete değil, karşı tarafa istek olarak gider.
    func sendMessageRequest(to profileID: UUID, body: String, storyID: UUID?) async throws
    func fetchMessageRequests() async throws -> [MessageRequest]
    /// Kabul, eşleşmeyi kurup ilk mesajı sohbete yazar ve eşleşmenin kimliğini döner.
    func acceptMessageRequest(_ requestID: UUID) async throws -> UUID
    func declineMessageRequest(_ requestID: UUID) async throws
    /// Kartlardaki aktiflik etiketi `last_active_at`'e bakıyor; bu alan hiçbir yerde
    /// güncellenmediği için herkes sürekli "Bu hafta aktif" görünüyordu.
    func touchLastActive() async throws
    func fetchStories() async throws -> [CampusStory]
    func publishStory(imageData: Data, caption: String, placeID: UUID?) async throws
    func deleteStory(_ storyID: UUID) async throws
    /// Süresi dolmuş kendi story'lerini siler (satır + dosya). Aksi halde her
    /// paylaşım depolamada kalıcı olarak yer kaplıyor.
    func purgeMyExpiredStories() async
    func markStoryViewed(_ storyID: UUID) async throws
    func fetchStoryViews(_ storyID: UUID) async throws -> [StoryViewRecord]
    /// Kulüpler ve kullanıcının üye olduğu kulüplerin kimlikleri.
    func fetchClubs() async throws -> (clubs: [CampusClub], joinedIDs: Set<UUID>)
    func setClubMembership(_ clubID: UUID, joined: Bool) async throws
    /// Yer görünürlüğü. `placeID` nil ise görünürlük kapatılır.
    func setVisiblePlace(_ placeID: UUID?) async throws
    func fetchPeopleAtPlace(_ placeID: UUID) async throws -> [StudentProfile]
    /// Profil ziyaretleri. Kayıt yalnızca RPC ile oluşur; istemci doğrudan yazamaz.
    func recordProfileVisit(_ profileID: UUID) async throws
    func fetchProfileVisits() async throws -> [ProfileVisit]
    /// Eşleşmeyi sonlandırır. Engellemekten farklı: karşı taraf engellenmiş olmaz.
    func unmatch(_ matchID: UUID) async throws
}

struct BackendConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var current: BackendConfiguration? {
        guard let url = AppSecrets.supabaseURL, url.scheme == "https" else { return nil }
        let key = AppSecrets.supabasePublishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return BackendConfiguration(url: url, publishableKey: key)
    }

    static var isConfigured: Bool { current != nil }
}

/// Supabase yapılandırması eksikken kullanılan servis. Her çağrıda net bir hata verir.
///
/// Eskiden bu durumda uygulama sessizce demo verisine düşüyordu; yapılandırma hatası
/// çalışan bir uygulama gibi göründüğü için fark edilmiyordu. Artık sorun hemen görünür.
struct UnconfiguredProductService: ProductService {
    var currentUserID: UUID? { nil }
    var currentUserEmail: String? { nil }

    private func fail() throws -> Never { throw BackendServiceError.missingConfiguration }

    func signInWithApple(idToken: String, nonce: String) async throws { try fail() }
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async throws { try fail() }
    func requestEmailSignInLink(email: String) async throws { try fail() }
    func completeEmailSignIn(url: URL) async throws { try fail() }
    func restoreSession() async throws -> UUID? { nil }
    func signOut() async throws {}
    func deleteAccount() async throws { try fail() }
    func saveProfile(_ draft: ProfileDraft) async throws { try fail() }
    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile] { try fail() }
    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult { try fail() }
    func fetchConversations() async throws -> [Conversation] { try fail() }
    func sendMessage(_ message: Message, matchID: UUID) async throws -> Message { try fail() }
    func markConversationRead(matchID: UUID) async throws { try fail() }
    func setMessageReaction(messageID: UUID, reaction: String?) async throws { try fail() }
    func deleteMessage(_ messageID: UUID) async throws { try fail() }
    func editMessage(_ messageID: UUID, body: String) async throws { try fail() }
    func setStoryLiked(_ storyID: UUID, liked: Bool) async throws { try fail() }
    func isStoryLiked(_ storyID: UUID) async throws -> Bool { try fail() }
    func fetchFeed() async throws -> [BackendPost] { try fail() }
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost { try fail() }
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment { try fail() }
    func deletePost(_ postID: UUID) async throws { try fail() }
    func deleteComment(_ commentID: UUID) async throws { try fail() }
    func fetchMyProfile() async throws -> ProfileDraft? { try fail() }
    func submitPurchase(jws: String, productID: String) async throws { try fail() }
    func fetchMyPlan() async throws -> SubscriptionTier { try fail() }
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult { try fail() }
    func updateAvatar(_ imageData: Data?) async throws -> URL? { try fail() }
    func updateGallery(_ images: [Data]) async throws -> [URL] { try fail() }
    func blockUser(_ profileID: UUID) async throws { try fail() }
    func unblockUser(_ profileID: UUID) async throws { try fail() }
    func fetchBlockedProfiles() async throws -> [BlockedProfile] { try fail() }
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws { try fail() }
    func fetchReports() async throws -> [ModerationReport] { try fail() }
    func fetchAdmirers() async throws -> [Admirer] { try fail() }
    func resolveReport(_ reportID: UUID, resolution: String) async throws { try fail() }
    func moderatorDeletePost(_ postID: UUID) async throws { try fail() }
    func setAccountActive(_ profileID: UUID, active: Bool) async throws { try fail() }
    func messageStream() -> AsyncStream<RealtimeMessage> { AsyncStream { $0.finish() } }
    func setPostLiked(_ postID: UUID, liked: Bool) async throws { try fail() }
    func setPostSaved(_ postID: UUID, saved: Bool) async throws { try fail() }
    func fetchSavedPosts() async throws -> [BackendPost] { try fail() }
    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails { try fail() }
    func resetPasses() async throws { try fail() }
    func fetchNotifications() async throws -> [BackendNotification] { try fail() }
    func markNotificationRead(_ notificationID: UUID) async throws { try fail() }
    func markAllNotificationsRead() async throws { try fail() }
    func registerDeviceToken(_ token: String) async throws { try fail() }
    func fetchPlaces() async throws -> [CampusPlace] { try fail() }
    func fetchMeetingRequests() async throws -> [MeetingRequest] { try fail() }
    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws { try fail() }
    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws -> UUID? { try fail() }
    func sendMessageRequest(to profileID: UUID, body: String, storyID: UUID?) async throws { try fail() }
    func fetchMessageRequests() async throws -> [MessageRequest] { try fail() }
    func acceptMessageRequest(_ requestID: UUID) async throws -> UUID { try fail() }
    func declineMessageRequest(_ requestID: UUID) async throws { try fail() }
    func touchLastActive() async throws {}
    func fetchStories() async throws -> [CampusStory] { try fail() }
    func publishStory(imageData: Data, caption: String, placeID: UUID?) async throws { try fail() }
    func deleteStory(_ storyID: UUID) async throws { try fail() }
    func purgeMyExpiredStories() async {}
    func markStoryViewed(_ storyID: UUID) async throws { try fail() }
    func fetchStoryViews(_ storyID: UUID) async throws -> [StoryViewRecord] { try fail() }
    func fetchClubs() async throws -> (clubs: [CampusClub], joinedIDs: Set<UUID>) { try fail() }
    func setClubMembership(_ clubID: UUID, joined: Bool) async throws { try fail() }
    func setVisiblePlace(_ placeID: UUID?) async throws { try fail() }
    func fetchPeopleAtPlace(_ placeID: UUID) async throws -> [StudentProfile] { try fail() }
    func recordProfileVisit(_ profileID: UUID) async throws { try fail() }
    func fetchProfileVisits() async throws -> [ProfileVisit] { try fail() }
    func unmatch(_ matchID: UUID) async throws { try fail() }
}

enum ProductServiceFactory {
    static func make() -> any ProductService {
        guard let configuration = BackendConfiguration.current else {
            return UnconfiguredProductService()
        }
        return SupabaseProductService(configuration: configuration)
    }
}

/// Kişi profilinde gösterilen ek veriler.
///
/// Hepsi ayrıca çekiliyor çünkü gönderi ve story sorguları yazar için yalnızca
/// temel alanları getiriyor: ilgi alanları boş, galeri yok, rozet yok. Gönderiler
/// de bellekteki akıştan süzülmüyor — akış o an yüklü olmayabilir ve akışta
/// olmayan eski gönderiler zaten hiç görünmezdi.
struct PersonDetails: Sendable {
    var interests: [String]
    var galleryURLs: [URL]
    /// Ana profil fotoğrafı. Navigasyondaki `StudentProfile.imageURL` bazen
    /// imzalanamamış / eksik geliyor; detay ekranı bunu yeniden çeker.
    var avatarURL: URL?
    /// `nil` = öğrenilemedi, `.none` = rozeti yok. İkisi bir değil: eskiden
    /// rozet sorgusu boş dönünce `.none` yazılıyor ve elimizdeki doğru rozeti
    /// eziyordu — bir ağ hıçkırığı kurucu rozetini sessizce siliyordu.
    var badge: ProfileBadge?
    var posts: [BackendPost]
}
