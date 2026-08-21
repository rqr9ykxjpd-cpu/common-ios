#if DEBUG
import Foundation
import UIKit

/// Sunucu olmadan uygulamayı gezebilmek için örnek veri servisi.
///
/// **Bu dosya `#if DEBUG` içinde. App Store'a yüklenen Release derlemesinde
/// derlenmiyor, yani ürüne sızması mümkün değil.**
// MARK: - Servis

struct SampleProductService: ProductService {
    private let store = SampleStore()
    /// `false` verilirse sunucuda profil yokmuş gibi davranır; `restoreBackendSession`
    /// da kullanıcıyı kayıt akışına yönlendirir. Gerçek yeni kullanıcı yolunu sunucu
    /// olmadan görebilmek için.
    private let hasProfile: Bool

    init(hasProfile: Bool = true) {
        self.hasProfile = hasProfile
    }

    var currentUserID: UUID? { SampleData.me.id }
    var currentUserEmail: String? { "ornek@yalova.edu.tr" }

    // Oturum
    func signInWithApple(idToken: String, nonce: String) async throws {}
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async throws {}
    func requestEmailSignInLink(email: String) async throws {}
    func completeEmailSignIn(url: URL) async throws {}
    func restoreSession() async throws -> UUID? { SampleData.me.id }
    func signOut() async throws {}
    func deleteAccount() async throws {}

    // Profil
    func saveProfile(_ draft: ProfileDraft) async throws { await store.save(draft) }
    // Örnek veride sunucu yok: satın alma bildirimi sessizce yutuluyor,
    // kademe `-tier` argümanıyla elle veriliyor (bkz. CampusApp).
    func submitPurchase(jws: String, productID: String) async throws {}
    func fetchMyPlan() async throws -> SubscriptionTier { .free }

    func fetchMyProfile() async throws -> ProfileDraft? { hasProfile ? await store.myDraft() : nil }
    /// Örnek veride depolama yok, imzalı adres de yok. Yine de boş dönmüyoruz:
    /// fotoğraf zorunluluğu kapısı (bkz. `AppState.requiresAvatarStep`) örnek
    /// veriyle gezerken uygulamayı kayıt akışına düşürüyor, hiçbir ekran
    /// görülemiyordu. Bu adres yalnızca "fotoğrafı var" demek için.
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult {
        ProfilePhotosResult(avatarURL: URL(string: "sample://avatar"), galleryURLs: [])
    }
    func updateAvatar(_ imageData: Data?) async throws -> URL? { nil }
    func updateGallery(_ images: [Data]) async throws -> [URL] { [] }

    // Keşif
    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile] {
        await store.takeCandidates(offset: offset, limit: limit)
    }
    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult {
        await store.react(to: profileID, liked: liked)
    }

    // Sohbet
    func fetchConversations() async throws -> [Conversation] { await store.allConversations() }
    func sendMessage(_ message: Message, matchID: UUID) async throws -> Message {
        await store.append(message, to: matchID)
    }
    func markConversationRead(matchID: UUID) async throws { await store.markRead(matchID) }
    func setMessageReaction(messageID: UUID, reaction: String?) async throws {
        await store.setReaction(messageID, reaction: reaction)
    }
    func deleteMessage(_ messageID: UUID) async throws {}
    func editMessage(_ messageID: UUID, body: String) async throws {}
    func setStoryLiked(_ storyID: UUID, liked: Bool) async throws {}
    func isStoryLiked(_ storyID: UUID) async throws -> Bool { false }
    func messageStream() -> AsyncStream<RealtimeMessage> { AsyncStream { $0.finish() } }
    func unmatch(_ matchID: UUID) async throws { await store.removeConversation(matchID) }

    // Akış
    func fetchFeed() async throws -> [BackendPost] { await store.allPosts() }
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost {
        let post = SampleData.newPost(caption: caption, placeName: placeName, imageData: imageData)
        await store.insert(post)
        return post
    }
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        let comment = BackendComment(
            id: UUID(),
            postID: postID,
            authorID: SampleData.me.id,
            authorName: SampleData.me.name,
            authorAvatarURL: nil,
            body: body,
            createdAt: .now
        )
        await store.addComment(comment)
        return comment
    }
    func deletePost(_ postID: UUID) async throws { await store.removePost(postID) }
    func deleteComment(_ commentID: UUID) async throws { await store.removeComment(commentID) }
    func setPostLiked(_ postID: UUID, liked: Bool) async throws { await store.setLiked(postID, liked: liked) }
    func setPostSaved(_ postID: UUID, saved: Bool) async throws { await store.setSaved(postID, saved: saved) }
    func resetPasses() async throws {}

    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails {
        // Rozet sabit `.none` idi ve örnek modda kurucu rozetini eziyordu:
        // kurucuya özel görünümü geliştirirken hiç görünmüyordu.
        let kisi = await store.profile(id: profileID)
        return PersonDetails(
            interests: kisi.map { Array($0.interests) } ?? ["Kahve", "Fotoğraf", "Yürüyüş"],
            galleryURLs: [],
            badge: kisi?.badge,
            posts: await store.allPosts().filter { $0.authorID == profileID }
        )
    }

    func fetchSavedPosts() async throws -> [BackendPost] { await store.allPosts().filter(\.saved) }

    // Güvenlik
    func blockUser(_ profileID: UUID) async throws {}
    func unblockUser(_ profileID: UUID) async throws {}
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws {}
    func fetchReports() async throws -> [ModerationReport] { await store.allReports() }
    func resolveReport(_ reportID: UUID, resolution: String) async throws {
        await store.resolveReport(reportID, resolution: resolution)
    }
    func moderatorDeletePost(_ postID: UUID) async throws { await store.removePost(postID) }
    func setAccountActive(_ profileID: UUID, active: Bool) async throws {
        await store.setAccountActive(profileID, active: active)
    }

    // Bildirim
    func fetchNotifications() async throws -> [BackendNotification] { await store.allNotifications() }
    func markNotificationRead(_ notificationID: UUID) async throws {
        await store.markNotificationRead(notificationID)
    }
    func markAllNotificationsRead() async throws { await store.markAllNotificationsRead() }
    func registerDeviceToken(_ token: String) async throws {}
    func touchLastActive() async throws {}

    // Yer, story, kulüp, buluşma
    func fetchPlaces() async throws -> [CampusPlace] { await store.allPlaces() }
    func fetchMeetingRequests() async throws -> [MeetingRequest] { await store.allMeetingRequests() }
    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws {
        await store.addMeetingRequest(to: profileID, placeID: placeID)
    }
    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws {
        await store.respondToMeetingRequest(requestID, accept: accept)
    }
    func sendMessageRequest(to profileID: UUID, body: String, storyID: UUID?) async throws {
        await store.addMessageRequest(to: profileID, body: body)
    }
    func fetchMessageRequests() async throws -> [MessageRequest] { await store.allMessageRequests() }
    func acceptMessageRequest(_ requestID: UUID) async throws -> UUID {
        guard let eslesme = await store.respondToMessageRequest(requestID, accept: true) else {
            throw BackendServiceError.missingSession
        }
        return eslesme
    }
    func declineMessageRequest(_ requestID: UUID) async throws {
        _ = await store.respondToMessageRequest(requestID, accept: false)
    }
    func fetchStories() async throws -> [CampusStory] { await store.allStories() }
    func publishStory(imageData: Data, caption: String, placeID: UUID?) async throws {
        let places = await store.allPlaces()
        await store.addStory(
            CampusStory(
                author: SampleData.me,
                localImageData: imageData,
                caption: caption,
                place: placeID.flatMap { id in places.first { $0.id == id } },
                isMine: true
            )
        )
    }
    func deleteStory(_ storyID: UUID) async throws { await store.removeStory(storyID) }
    func purgeMyExpiredStories() async {}
    func markStoryViewed(_ storyID: UUID) async throws { await store.markStoryViewed(storyID) }
    func fetchStoryViews(_ storyID: UUID) async throws -> [StoryViewRecord] {
        await store.storyViews(storyID)
    }
    func fetchClubs() async throws -> (clubs: [CampusClub], joinedIDs: Set<UUID>) {
        await store.allClubs()
    }
    func setClubMembership(_ clubID: UUID, joined: Bool) async throws {
        await store.setClubMembership(clubID, joined: joined)
    }
    func setVisiblePlace(_ placeID: UUID?) async throws { await store.setVisiblePlace(placeID) }
    func fetchPeopleAtPlace(_ placeID: UUID) async throws -> [StudentProfile] {
        await store.peopleAtPlace(placeID)
    }

    // Profil ziyaretleri
    func recordProfileVisit(_ profileID: UUID) async throws {}
    func fetchProfileVisits() async throws -> [ProfileVisit] { await store.allVisits() }
}

// MARK: - Değiştirici yardımcılar

extension BackendPost {
    func copy(liked: Bool? = nil, saved: Bool? = nil, likeCount: Int? = nil, comments: [BackendComment]? = nil) -> BackendPost {
        BackendPost(
            id: id, authorID: authorID, authorName: authorName, authorBirthDate: authorBirthDate,
            authorUniversity: authorUniversity, authorDepartment: authorDepartment, authorYear: authorYear,
            authorBio: authorBio, authorVerified: authorVerified, authorBadge: authorBadge,
            authorAvatarURL: authorAvatarURL,
            caption: caption, placeName: placeName, imageData: imageData, createdAt: createdAt,
            comments: comments ?? self.comments,
            likeCount: likeCount ?? self.likeCount,
            liked: liked ?? self.liked,
            saved: saved ?? self.saved
        )
    }
}

extension BackendNotification {
    func copy(isRead: Bool) -> BackendNotification {
        BackendNotification(
            id: id, kind: kind, title: title, body: body, actorID: actorID, actorName: actorName,
            actorAvatarURL: actorAvatarURL, matchID: matchID, isRead: isRead, createdAt: createdAt
        )
    }
}

#endif
