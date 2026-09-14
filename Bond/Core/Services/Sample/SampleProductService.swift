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
    func signInWithEmail(email: String, password: String) async throws {}
    func restoreSession() async throws -> UUID? { SampleData.me.id }
    func signOut() async throws {}
    func deleteAccount() async throws {}

    // Profil
    func saveProfile(_ draft: ProfileDraft) async throws { await store.save(draft) }
    // Örnek veride sunucu yok: satın alma bildirimi sessizce yutuluyor,
    // kademe `-tier` argümanıyla elle veriliyor (bkz. BondApp).
    func submitPurchase(jws: String, productID: String) async throws {}
    func fetchMyPlan() async throws -> SubscriptionTier { .free }

    func fetchMyProfile() async throws -> ProfileDraft? { hasProfile ? await store.myDraft() : nil }
    /// Örnek veride imzalı adres yok. BondApp yerel görseli avatarData'ya yükler.
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult {
        ProfilePhotosResult(avatarURL: SampleData.me.imageURL, galleryURLs: SampleData.profiles[0].galleryImageURLs)
    }
    func updateAvatar(_ imageData: Data?) async throws -> URL? { nil }
    func updateGallery(_ images: [Data]) async throws -> [URL] {
        await store.replaceGalleryCount(images.count)
        return []
    }
    func appendGalleryPhoto(_ image: Data) async throws -> URL {
        try await store.appendGalleryPhoto()
    }

    // Kampüs insanları
    func fetchCampusPeople(offset: Int, limit: Int) async throws -> [StudentProfile] {
        await store.campusPeople(offset: offset, limit: limit)
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
    func countMyPosts() async throws -> Int {
        await store.allPosts().filter { $0.authorID == SampleData.me.id }.count
    }
    func createPost(caption: String, placeName: String?, imageData: Data?, kind: PostKind) async throws -> BackendPost {
        let count = await store.allPosts().filter { $0.authorID == SampleData.me.id }.count
        if count >= CampusLimits.maxPostsPerUser { throw BackendServiceError.postLimit }
        let post = SampleData.newPost(caption: caption, placeName: placeName, imageData: imageData, kind: kind)
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
    func setPostVote(_ postID: UUID, value: Int) async throws { await store.setPostVote(postID, value: value) }
    func boostPost(_ postID: UUID, extra: Int) async throws -> Int { await store.boost(postID, extra: extra) }
    func boostComment(_ commentID: UUID, extra: Int) async throws -> Int { await store.boostComment(commentID, extra: extra) }
    func setPostPin(_ postID: UUID, slot: Int?) async throws { await store.setPin(postID, slot: slot) }
    func fetchPostVoters(_ postID: UUID) async throws -> [PostVoter] {
        // Örnek veride oy satırı yok; demo için ilk birkaç profil oy vermiş gibi.
        SampleData.profiles.prefix(4).enumerated().map { i, p in
            PostVoter(id: p.id, name: p.name, avatarURL: nil, value: i == 2 ? -1 : 1, avatarAssetName: p.imageAssetName)
        }
    }

    func fetchCommentVoters(_ commentID: UUID) async throws -> [PostVoter] {
        SampleData.profiles.dropFirst(2).prefix(3).enumerated().map { i, p in
            PostVoter(id: p.id, name: p.name, avatarURL: nil, value: i == 1 ? -1 : 1, avatarAssetName: p.imageAssetName)
        }
    }
    func setCommentVote(_ commentID: UUID, value: Int) async throws { await store.setCommentVote(commentID, value: value) }
    func setPostSaved(_ postID: UUID, saved: Bool) async throws { await store.setSaved(postID, saved: saved) }

    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails {
        // Rozet sabit `.none` idi ve örnek modda kurucu rozetini eziyordu:
        // kurucuya özel görünümü geliştirirken hiç görünmüyordu.
        if ProcessInfo.processInfo.arguments.contains("-preview-details-error") { throw URLError(.notConnectedToInternet) }
        let kisi = await store.profile(id: profileID)
        return PersonDetails(
            interests: kisi.map { Array($0.interests) } ?? ["Kahve", "Fotoğraf", "Yürüyüş"],
            galleryURLs: kisi?.galleryImageURLs ?? [],
            avatarURL: kisi?.imageURL,
            badge: kisi?.badge,
            posts: []
        )
    }

    func fetchPersonPosts(_ profileID: UUID) async -> [BackendPost] {
        await store.allPosts().filter { $0.authorID == profileID }
    }

    func fetchSavedPosts() async throws -> [BackendPost] { await store.allPosts().filter(\.saved) }

    // Güvenlik
    func blockUser(_ profileID: UUID) async throws { await store.block(profileID) }
    func unblockUser(_ profileID: UUID) async throws { await store.unblock(profileID) }
    func fetchBlockedProfiles() async throws -> [BlockedProfile] { await store.allBlocked() }
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws {
        await store.addReport(profileID: profileID, reason: reason, details: details)
    }
    func reportContent(_ target: ReportTarget, reason: ReportReason, details: String?) async throws {
        try await store.addContentReport(target, reason: reason, details: details)
    }
    func fetchReports() async throws -> [ModerationReport] { await store.allReports() }
    func resolveReport(_ reportID: UUID, resolution: String) async throws {
        try await store.resolveReport(reportID, resolution: resolution)
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
    func unregisterDeviceToken(_ token: String) async throws {}
    func touchLastActive() async throws {}

    // Yer, story, kulüp, buluşma
    func fetchPlaces() async throws -> [CampusPlace] { await store.allPlaces() }
    func fetchPlacePresence() async throws -> [PlacePresenceSummary] { await store.placePresence() }
    func fetchMeetingRequests() async throws -> [MeetingRequest] { await store.allMeetingRequests() }
    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws {
        await store.addMeetingRequest(to: profileID, placeID: placeID)
    }
    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws -> UUID? {
        await store.respondToMeetingRequest(requestID, accept: accept)
    }
    func sendMessageRequest(to profileID: UUID, body: String, storyID: UUID?) async throws {
        await store.addMessageRequest(to: profileID, body: body)
    }
    func recordLeftSwipe(on profileID: UUID) async throws {}
    func fetchFounderStats() async throws -> FounderStats {
        var s = FounderStats()
        s.usersTotal = 184; s.usersVerified = 171; s.usersToday = 9; s.usersWeek = 41
        s.onlineNow = 9; s.activeToday = 63; s.activeWeek = 128; s.pushDevices = 140
        s.plus = 7; s.pro = 3
        s.postsTotal = 412; s.postsToday = 18; s.commentsTotal = 1290; s.votesTotal = 3877; s.storiesActive = 14
        s.rightSwipes = 356; s.leftSwipes = 522; s.matches = 48; s.messagesTotal = 2210
        s.presentNow = 11; s.reportsOpen = 1
        return s
    }

    func sendFounderBroadcast(title: String, body: String, testOnly: Bool) async throws -> Int { testOnly ? 1 : 184 }

    func fetchFounderUsers(search: String) async throws -> [FounderUser] {
        SampleData.profiles.enumerated().map { i, p in
            FounderUser(id: p.id, name: p.name, department: p.department, academicYear: p.year,
                        avatarURL: nil, badge: i == 1 ? .moderator : .none, isVerified: true, isActive: i != 4,
                        plan: i == 0 ? .pro : (i == 2 ? .plus : .free),
                        createdAt: SampleData.hours(Double(24 * (i + 1))), lastActiveAt: SampleData.hours(Double(i * 3)),
                        avatarAssetName: p.imageAssetName)
        }.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    func founderGrantPlan(_ userID: UUID, plan: SubscriptionTier, days: Int?) async throws -> SubscriptionTier { plan }
    func founderSetModerator(_ userID: UUID, enabled: Bool) async throws -> ProfileBadge { enabled ? .moderator : .none }
    func founderSetActive(_ userID: UUID, active: Bool) async throws -> Bool { active }
    func fetchFounderDaily(days: Int) async throws -> [FounderDay] {
        (0..<days).reversed().map { i in
            FounderDay(day: Calendar.current.startOfDay(for: .now).addingTimeInterval(-Double(i) * 86_400),
                       newUsers: [3, 5, 2, 9, 4, 7, 6][i % 7], activeUsers: [40, 52, 38, 61, 47, 66, 63][i % 7], posts: [12, 18, 9, 22, 15, 20, 18][i % 7], matches: [2, 4, 1, 6, 3, 5, 4][i % 7])
        }
    }
    func fetchFounderAnnouncements() async throws -> [FounderAnnouncement] {
        [FounderAnnouncement(title: "Hoş geldiniz", body: "Common açıldı, ilk sorunu sor.", sentAt: SampleData.hours(30), recipients: 184)]
    }

    func fetchProfileSwipers() async throws -> [ProfileSwiper] {
        // Demo: iki sağa, bir sola, bir de bağlantı kurulmuş.
        let p = SampleData.profiles
        return [
            ProfileSwiper(id: p[0].id, name: p[0].name, avatarURL: nil, swipedRight: true, swipedAt: SampleData.hours(1), isMatched: true, avatarAssetName: p[0].imageAssetName),
            ProfileSwiper(id: p[2].id, name: p[2].name, avatarURL: nil, swipedRight: false, swipedAt: SampleData.hours(3), isMatched: false, avatarAssetName: p[2].imageAssetName),
            ProfileSwiper(id: p[3].id, name: p[3].name, avatarURL: nil, swipedRight: true, swipedAt: SampleData.hours(7), isMatched: false, avatarAssetName: p[3].imageAssetName),
            ProfileSwiper(id: p[4].id, name: p[4].name, avatarURL: nil, swipedRight: false, swipedAt: SampleData.date(1.2), isMatched: false, avatarAssetName: p[4].imageAssetName),
        ]
    }
    func sendRightSwipe(to profileID: UUID) async throws -> RightSwipeOutcome {
        try await store.addRightSwipe(to: profileID)
    }
    /// Kaydırmalar görünmez: tek yönlü istek listesi artık boş (sunucu da boş döner).
    func fetchIntroductionRequests() async throws -> [StudentProfile] { [] }
    func fetchMessageRequests() async throws -> [MessageRequest] { await store.allMessageRequests() }
    func acceptMessageRequest(_ requestID: UUID) async throws -> UUID {
        guard let matchID = await store.respondToMessageRequest(requestID, accept: true) else {
            throw BackendServiceError.missingSession
        }
        return matchID
    }
    func declineMessageRequest(_ requestID: UUID) async throws {
        _ = await store.respondToMessageRequest(requestID, accept: false)
    }
    func fetchStories() async throws -> [CampusStory] { await store.allStories() }
    func publishStory(_ upload: StoryUpload, caption: String, placeID: UUID?) async throws {
        let places = await store.allPlaces()
        let place = placeID.flatMap { id in places.first { $0.id == id } }
        switch upload {
        case .photo(let imageData):
            await store.addStory(
                CampusStory(
                    author: SampleData.me,
                    localImageData: imageData,
                    caption: caption,
                    place: place,
                    isMine: true
                )
            )
        case .video(let fileURL, let posterJPEG, let duration):
            await store.addStory(
                CampusStory(
                    author: SampleData.me,
                    localImageData: posterJPEG,
                    caption: caption,
                    place: place,
                    isMine: true,
                    mediaKind: .video,
                    videoURL: fileURL,
                    duration: duration
                )
            )
        }
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
    func setGhostMode(_ enabled: Bool) async throws {}
}

// MARK: - Değiştirici yardımcılar

extension BackendPost {
    func copy(liked: Bool? = nil, downvoted: Bool? = nil, saved: Bool? = nil, likeCount: Int? = nil, comments: [BackendComment]? = nil, boost: Int? = nil, pinnedAt: Date?? = nil, pinnedSlot: Int?? = nil) -> BackendPost {
        BackendPost(
            id: id, authorID: authorID, authorName: authorName, authorBirthDate: authorBirthDate,
            authorUniversity: authorUniversity, authorDepartment: authorDepartment, authorYear: authorYear,
            authorBio: authorBio, authorVerified: authorVerified, authorBadge: authorBadge,
            authorAvatarURL: authorAvatarURL,
            caption: caption, placeName: placeName, kind: kind, imageData: imageData, imageURL: imageURL, createdAt: createdAt,
            comments: comments ?? self.comments,
            likeCount: likeCount ?? self.likeCount,
            liked: liked ?? self.liked,
            downvoted: downvoted ?? self.downvoted,
            saved: saved ?? self.saved,
            boost: boost ?? self.boost,
            pinnedAt: pinnedAt ?? self.pinnedAt,
            pinnedSlot: pinnedSlot ?? self.pinnedSlot
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
