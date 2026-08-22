#if DEBUG
import Foundation
import UIKit

/// Sunucu olmadan uygulamayı gezebilmek için örnek veri servisi.
///
/// **Bu dosya `#if DEBUG` içinde. App Store'a yüklenen Release derlemesinde
/// derlenmiyor, yani ürüne sızması mümkün değil.** Daha önce kaldırılan demo
/// modundan farkı bu: o, yapılandırma eksikken canlıda da sessizce sahte veriye
/// düşüyordu ve hata çalışan bir uygulama gibi görünüyordu.
///
/// Kendiliğinden devreye girmez; yalnızca karşılama ekranındaki (yine yalnızca
/// DEBUG'da görünen) "Örnek veriyle gez" düğmesiyle seçilir.
///
/// Veri bellekte tutulur: beğeni, mesaj, yorum ve kaydetme uygulama açık kaldığı
/// sürece korunur, kapanınca sıfırlanır.
actor SampleStore {
    var profiles: [StudentProfile]
    var conversations: [Conversation]
    var posts: [BackendPost]
    var notifications: [BackendNotification]
    var stories: [CampusStory]
    var clubs: [CampusClub]
    var joinedClubIDs: Set<UUID>
    var meetingRequests: [MeetingRequest]
    var visits: [ProfileVisit]
    var places: [CampusPlace]
    var visiblePlaceID: UUID?
    var draft: ProfileDraft

    let me: StudentProfile

    init() {
        let places = SampleData.places
        self.places = places
        self.profiles = SampleData.profiles
        self.me = SampleData.me
        self.draft = SampleData.myDraft
        self.clubs = SampleData.clubs(places: places)
        self.joinedClubIDs = []
        self.conversations = SampleData.conversations
        self.posts = SampleData.posts
        self.notifications = SampleData.notifications
        self.stories = SampleData.stories(places: places)
        self.meetingRequests = SampleData.meetingRequests(places: places)
        self.visits = SampleData.visits
        self.visiblePlaceID = nil
    }

    // MARK: Keşif

    func takeCandidates(offset: Int, limit: Int) -> [StudentProfile] {
        guard offset < profiles.count else { return [] }
        return Array(profiles[offset..<min(offset + limit, profiles.count)])
    }

    /// Örnek veride her üçüncü beğeni eşleşmeye dönüyor; eşleşme anı ekranı ve
    /// oradan açılan sohbet böylece denenebiliyor.
    func react(to profileID: UUID, liked: Bool) -> DiscoveryReactionResult {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else {
            return DiscoveryReactionResult(matched: false, matchID: nil)
        }
        let profile = profiles.remove(at: index)
        guard liked, profile.compatibility >= 80 else {
            return DiscoveryReactionResult(matched: false, matchID: nil)
        }
        let matchID = UUID()
        conversations.insert(
            Conversation(id: matchID, profile: profile, messages: [], updatedAt: .now, unreadCount: 0),
            at: 0
        )
        return DiscoveryReactionResult(matched: true, matchID: matchID)
    }

    // MARK: Sohbet

    func allConversations() -> [Conversation] { conversations }

    func append(_ message: Message, to matchID: UUID) -> Message {
        guard let index = conversations.firstIndex(where: { $0.id == matchID }) else { return message }
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        return message
    }

    func markRead(_ matchID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == matchID }) else { return }
        conversations[index].unreadCount = 0
    }

    func setReaction(_ messageID: UUID, reaction: String?) {
        for index in conversations.indices {
            guard let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == messageID }) else { continue }
            conversations[index].messages[messageIndex].reaction = reaction
            return
        }
    }

    func removeConversation(_ matchID: UUID) {
        conversations.removeAll { $0.id == matchID }
    }

    // MARK: Akış

    func allPosts() -> [BackendPost] { posts }

    func insert(_ post: BackendPost) { posts.insert(post, at: 0) }

    func removePost(_ postID: UUID) { posts.removeAll { $0.id == postID } }

    func setLiked(_ postID: UUID, liked: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index] = posts[index].copy(liked: liked, likeCount: max(0, posts[index].likeCount + (liked ? 1 : -1)))
    }

    func setSaved(_ postID: UUID, saved: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index] = posts[index].copy(saved: saved)
    }

    func addComment(_ comment: BackendComment) {
        guard let index = posts.firstIndex(where: { $0.id == comment.postID }) else { return }
        posts[index] = posts[index].copy(comments: posts[index].comments + [comment])
    }

    func removeComment(_ commentID: UUID) {
        for index in posts.indices where posts[index].comments.contains(where: { $0.id == commentID }) {
            posts[index] = posts[index].copy(comments: posts[index].comments.filter { $0.id != commentID })
            return
        }
    }

    // MARK: Bildirim

    func allNotifications() -> [BackendNotification] { notifications }

    func markNotificationRead(_ id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index] = notifications[index].copy(isRead: true)
    }

    func markAllNotificationsRead() {
        notifications = notifications.map { $0.copy(isRead: true) }
    }

    // MARK: Story

    func allStories() -> [CampusStory] { stories }

    func markStoryViewed(_ id: UUID) {
        guard let index = stories.firstIndex(where: { $0.id == id }) else { return }
        stories[index].viewed = true
    }

    func storyViews(_ id: UUID) -> [StoryViewRecord] {
        stories.first { $0.id == id }?.viewRecords ?? []
    }

    func addStory(_ story: CampusStory) { stories.insert(story, at: 0) }

    func removeStory(_ id: UUID) { stories.removeAll { $0.id == id } }

    // MARK: Kulüp, yer, buluşma

    func allClubs() -> (clubs: [CampusClub], joinedIDs: Set<UUID>) { (clubs, joinedClubIDs) }

    func setClubMembership(_ id: UUID, joined: Bool) {
        if joined { joinedClubIDs.insert(id) } else { joinedClubIDs.remove(id) }
    }

    func allPlaces() -> [CampusPlace] { places }

    func setVisiblePlace(_ id: UUID?) { visiblePlaceID = id }

    /// Yerde görünen kişiler: örnek profillerin ilk üçü, artı kendin görünürsen sen.
    func peopleAtPlace(_ id: UUID) -> [StudentProfile] {
        Array(SampleData.profiles.prefix(3))
    }

    func allMeetingRequests() -> [MeetingRequest] { meetingRequests }

    // MARK: Moderasyon

    private var reports: [ModerationReport] = SampleData.reports
    private var suspended: Set<UUID> = []

    // MARK: Engellenenler

    private var blocked: [BlockedProfile] = SampleData.blockedProfiles

    func allBlocked() -> [BlockedProfile] { blocked }

    func block(_ profileID: UUID) {
        guard !blocked.contains(where: { $0.id == profileID }) else { return }
        let kisi = profiles.first { $0.id == profileID }
        blocked.insert(BlockedProfile(id: profileID, name: kisi?.name,
                                      imageURL: kisi?.imageURL, blockedAt: .now), at: 0)
    }

    func unblock(_ profileID: UUID) {
        blocked.removeAll { $0.id == profileID }
    }

    func allReports() -> [ModerationReport] {
        reports.map { rapor in
            var kopya = rapor
            kopya.reportedActive = !suspended.contains(rapor.reported.id)
            return kopya
        }
    }

    func resolveReport(_ id: UUID, resolution: String) {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        reports[index].handledAt = .now
        reports[index].resolution = resolution
    }

    func setAccountActive(_ profileID: UUID, active: Bool) {
        if active { suspended.remove(profileID) } else { suspended.insert(profileID) }
    }

    /// Kimlikten kişi. "Ben" de dahil: kendi profilime baktığımda da doğru
    /// rozet ve ilgi alanları gelsin.
    func profile(id: UUID) -> StudentProfile? {
        if id == SampleData.me.id { return SampleData.me }
        return profiles.first { $0.id == id }
    }

    func addMeetingRequest(to profileID: UUID, placeID: UUID) {
        guard let profile = SampleData.profiles.first(where: { $0.id == profileID }),
              let place = places.first(where: { $0.id == placeID }) else { return }
        meetingRequests.insert(
            MeetingRequest(profile: profile, place: place, direction: .outgoing, status: .pending),
            at: 0
        )
    }

    func respondToMeetingRequest(_ id: UUID, accept: Bool) -> UUID? {
        guard let index = meetingRequests.firstIndex(where: { $0.id == id }) else { return nil }
        meetingRequests[index].status = accept ? .accepted : .declined
        guard accept else { return nil }

        let profile = meetingRequests[index].profile
        if let existing = conversations.first(where: { $0.profile.id == profile.id }) {
            return existing.id
        }

        let conversation = Conversation(
            id: UUID(),
            profile: profile,
            messages: [],
            updatedAt: .now,
            unreadCount: 0
        )
        conversations.insert(conversation, at: 0)
        return conversation.id
    }

    // MARK: Yanıt istekleri

    private var messageRequests: [MessageRequest] = SampleData.messageRequests

    func allMessageRequests() -> [MessageRequest] { messageRequests }

    func addMessageRequest(to profileID: UUID, body: String) {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        messageRequests.insert(
            MessageRequest(id: UUID(), profile: profile, body: body,
                           direction: .outgoing, status: .pending, createdAt: .now),
            at: 0
        )
    }

    func respondToMessageRequest(_ id: UUID, accept: Bool) -> UUID? {
        guard let index = messageRequests.firstIndex(where: { $0.id == id }) else { return nil }
        messageRequests[index].status = accept ? .accepted : .declined
        guard accept else { return nil }
        // Örnek veride kabul, var olan bir sohbete bağlanıyor: gerçek akışta
        // sunucu eşleşmeyi kuruyor.
        return conversations.first(where: { $0.profile.id == messageRequests[index].profile.id })?.id
    }

    // MARK: Profil

    func allVisits() -> [ProfileVisit] { visits }

    func myDraft() -> ProfileDraft { draft }

    func save(_ newDraft: ProfileDraft) { draft = newDraft }
}

#endif
