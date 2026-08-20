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

    func addMeetingRequest(to profileID: UUID, placeID: UUID) {
        guard let profile = SampleData.profiles.first(where: { $0.id == profileID }),
              let place = places.first(where: { $0.id == placeID }) else { return }
        meetingRequests.insert(
            MeetingRequest(profile: profile, place: place, direction: .outgoing, status: .pending),
            at: 0
        )
    }

    func respondToMeetingRequest(_ id: UUID, accept: Bool) {
        guard let index = meetingRequests.firstIndex(where: { $0.id == id }) else { return }
        meetingRequests[index].status = accept ? .accepted : .declined
    }

    // MARK: Profil

    func allVisits() -> [ProfileVisit] { visits }

    func myDraft() -> ProfileDraft { draft }

    func save(_ newDraft: ProfileDraft) { draft = newDraft }
}

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
    func restoreSession() async throws -> UUID? { SampleData.me.id }
    func signOut() async throws {}
    func deleteAccount() async throws {}

    // Profil
    func saveProfile(_ draft: ProfileDraft) async throws { await store.save(draft) }
    func fetchMyProfile() async throws -> ProfileDraft? { hasProfile ? await store.myDraft() : nil }
    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult {
        ProfilePhotosResult(avatarURL: nil, galleryURLs: [])
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
    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails {
        PersonDetails(interests: ["Kahve", "Fotoğraf", "Yürüyüş"], galleryURLs: [],
                      badge: .none, posts: [])
    }

    func fetchSavedPosts() async throws -> [BackendPost] { await store.allPosts().filter(\.saved) }

    // Güvenlik
    func blockUser(_ profileID: UUID) async throws {}
    func unblockUser(_ profileID: UUID) async throws {}
    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws {}

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

private extension BackendPost {
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

private extension BackendNotification {
    func copy(isRead: Bool) -> BackendNotification {
        BackendNotification(
            id: id, kind: kind, title: title, body: body, actorID: actorID, actorName: actorName,
            actorAvatarURL: actorAvatarURL, matchID: matchID, isRead: isRead, createdAt: createdAt
        )
    }
}

// MARK: - Örnek içerik

enum SampleData {
    /// Örnek kayıtların kimlikleri sabit. Her açılışta yeni UUID üretilseydi
    /// `UserDefaults` her denemede bir hesap anahtarı daha biriktirirdi.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number)) ?? UUID()
    }

    static func date(_ daysAgo: Double) -> Date { .now.addingTimeInterval(-daysAgo * 86_400) }
    static func hours(_ hoursAgo: Double) -> Date { .now.addingTimeInterval(-hoursAgo * 3_600) }

    static let places: [CampusPlace] = [
        CampusPlace(id: id(20), name: "Merkez Kütüphane", area: "Merkez Kampüs"),
        CampusPlace(id: id(21), name: "Hazırlık Kantini", area: "Yabancı Diller"),
        CampusPlace(id: id(22), name: "Mühendislik Bahçesi", area: "Mühendislik Fakültesi"),
        CampusPlace(id: id(23), name: "Sahil Yürüyüş Yolu", area: "Kampüs dışı"),
        CampusPlace(id: id(24), name: "Spor Salonu", area: "Merkez Kampüs")
    ]

    static let me = StudentProfile(
        id: id(1),
        name: "Cem",
        age: 21,
        university: "YÜ",
        department: "Endüstri Mühendisliği",
        year: "3. sınıf",
        bio: "Kampüste kahve içmeyi ve uzun yürüyüşleri seven biri. Hafta sonları sahilde bulunurum.",
        interests: ["Kahve", "Fotoğraf", "Yürüyüş", "Podcast", "Basketbol"],
        imageURL: nil,
        imageAssetName: "profile-berk",
        compatibility: 100,
        isVerified: true,
        badge: .founder,
        relationshipIntent: .both
    )

    static var myDraft: ProfileDraft {
        var draft = ProfileDraft()
        draft.name = me.name
        draft.birthDate = Calendar.current.date(byAdding: .year, value: -me.age, to: .now) ?? .now
        draft.university = me.university
        draft.department = me.department
        draft.year = me.year
        draft.bio = me.bio
        draft.interests = Set(me.interests)
        draft.gender = .male
        draft.relationshipIntent = .both
        return draft
    }

    static let profiles: [StudentProfile] = [
        StudentProfile(
            id: id(10),
            name: "Ece", age: 21, university: "YÜ", department: "Görsel İletişim", year: "3. sınıf",
            bio: "Analog fotoğraf çekiyorum, kampüsün her köşesinde bir kare arıyorum.",
            interests: ["Fotoğraf", "Sinema", "Kahve", "Sergi"],
            imageURL: nil, imageAssetName: "profile-ece",
            compatibility: 92, isVerified: true, badge: .moderator,
            compatibilityReasons: ["3 ortak ilgi alanı", "İkiniz de kahve düşkünü"],
            relationshipIntent: .both, activeLabel: "Bugün aktif"
        ),
        StudentProfile(
            id: id(11),
            name: "Defne", age: 20, university: "YÜ", department: "Psikoloji", year: "2. sınıf",
            bio: "Kitap kulübünün en gürültücü üyesi. İyi bir tartışmaya hayır demem.",
            interests: ["Kitap", "Yürüyüş", "Podcast", "Kahve"],
            imageURL: nil, imageAssetName: "profile-defne",
            compatibility: 87, isVerified: true,
            compatibilityReasons: ["3 ortak ilgi alanı", "Aynı fakülte bahçesinde takılıyorsunuz"],
            relationshipIntent: .friendship, activeLabel: "2 saat önce aktif"
        ),
        StudentProfile(
            id: id(12),
            name: "Duru", age: 22, university: "YÜ", department: "Mimarlık", year: "4. sınıf",
            bio: "Maket bıçağıyla aram iyi. Sahil yürüyüşü teklif edene hayır demiyorum.",
            interests: ["Tasarım", "Yürüyüş", "Müzik", "Fotoğraf"],
            imageURL: nil, imageAssetName: "profile-duru",
            compatibility: 84, isVerified: false,
            compatibilityReasons: ["2 ortak ilgi alanı"],
            relationshipIntent: .both, activeLabel: "Bu hafta aktif"
        ),
        StudentProfile(
            id: id(13),
            name: "Selin", age: 21, university: "YÜ", department: "Hukuk", year: "3. sınıf",
            bio: "Sabah 7 antrenmanı, akşam 7 duruşma provası. Aramda kahve var.",
            interests: ["Koşu", "Kahve", "Münazara"],
            imageURL: nil, imageAssetName: "profile-selin",
            compatibility: 76, isVerified: true,
            compatibilityReasons: ["1 ortak ilgi alanı"],
        ),
        StudentProfile(
            id: id(14),
            name: "Mina", age: 20, university: "YÜ", department: "Bilgisayar Mühendisliği", year: "2. sınıf",
            bio: "Gece kodlayan, gündüz uyuyan biri. Bana iyi bir bug getir, arkadaş olalım.",
            interests: ["Yazılım", "Oyun", "Podcast", "Kahve"],
            imageURL: nil, imageAssetName: "profile-mina",
            compatibility: 81, isVerified: false,
            compatibilityReasons: ["2 ortak ilgi alanı", "Aynı kampüsteki geç saatçiler"],
            relationshipIntent: .friendship, activeLabel: "Bugün aktif"
        ),
        StudentProfile(
            id: id(15),
            name: "Arda", age: 23, university: "YÜ", department: "Makine Mühendisliği", year: "4. sınıf",
            bio: "Bisikletle kampüs turu atarım. Motor sesinden anlarım.",
            interests: ["Bisiklet", "Müzik", "Yürüyüş"],
            imageURL: nil, imageAssetName: "profile-arda",
            compatibility: 68, isVerified: false,
            compatibilityReasons: ["1 ortak ilgi alanı"],
        )
    ]

    static var conversations: [Conversation] {
        let ece = profiles[0]
        let defne = profiles[1]
        return [
            Conversation(
                id: UUID(),
                profile: ece,
                messages: [
                    Message(body: "Selam! Kartındaki kahve muhabbeti dikkatimi çekti 👀", isMine: false, sentAt: hours(5)),
                    Message(body: "Haha yakalandım. Kampüste favori yerin var mı?", isMine: true, sentAt: hours(4.6)),
                    Message(body: "Hazırlık kantini. Işık öğleden sonra çok güzel oluyor, fotoğraf için bire bir.", isMine: false, sentAt: hours(4.2), reaction: "❤️"),
                    Message(body: "O zaman yarın oraya uğrayalım mı?", isMine: true, sentAt: hours(1.1))
                ],
                updatedAt: hours(1.1),
                unreadCount: 0
            ),
            Conversation(
                id: UUID(),
                profile: defne,
                messages: [
                    Message(body: "Kitap kulübüne bu hafta geliyor musun?", isMine: false, sentAt: hours(26)),
                    Message(body: "Hangi kitabı tartışıyorsunuz?", isMine: true, sentAt: hours(25)),
                    Message(body: "Bu ay Türkçe çeviri bir polisiye. Seni de bekleriz!", isMine: false, sentAt: hours(3))
                ],
                updatedAt: hours(3),
                unreadCount: 1
            )
        ]
    }

    static var posts: [BackendPost] {
        [
            post(author: profiles[0], caption: "Ders sonrası planı: kendimizi dışarı atmak.",
                 place: "Hazırlık Kantini", asset: "post-cafe", createdAt: hours(2), likes: 34, liked: true, comments: [
                    ("Defne", "Ben de geliyorum!"),
                    ("Mina", "Işık gerçekten güzel olmuş")
                 ]),
            post(author: profiles[4], caption: "Vize haftası kütüphane kampı başladı. İkinci kahve gidiyor.",
                 place: "Merkez Kütüphane", asset: "post-study", createdAt: hours(7), likes: 21, liked: false, comments: [
                    ("Arda", "Dayan, iki gün kaldı")
                 ]),
            post(author: me, caption: "Sahil yürüyüşü her şeye iyi geliyor.",
                 place: "Sahil Yürüyüş Yolu", asset: "post-campus", createdAt: hours(20), likes: 47, liked: false, mine: true, comments: [
                    ("Ece", "Kare çok iyi olmuş"),
                    ("Selin", "Yarın da gidelim mi?")
                 ]),
            post(author: profiles[2], caption: "Maket teslimine 6 saat kala bahçede mola.",
                 place: "Mühendislik Bahçesi", asset: "post-quiet", createdAt: date(1.4), likes: 15, liked: false, comments: []),
            post(author: profiles[1], caption: "Kitap kulübü bu akşam toplanıyor, gelen gelsin.",
                 place: nil, asset: "post-club", createdAt: date(2.1), likes: 29, liked: true, comments: [
                    ("Duru", "Saat kaçta?")
                 ]),
            post(author: profiles[3], caption: "Sabah koşusu bitti, güne 1-0 öndeyim.",
                 place: nil, asset: "post-friends", createdAt: date(3), likes: 38, liked: false, comments: [])
        ]
    }

    private static func post(
        author: StudentProfile, caption: String, place: String?, asset: String,
        createdAt: Date, likes: Int, liked: Bool, mine: Bool = false,
        comments: [(String, String)]
    ) -> BackendPost {
        let postID = UUID()
        return BackendPost(
            id: postID,
            authorID: author.id,
            authorName: author.name,
            authorBirthDate: Calendar.current.date(byAdding: .year, value: -author.age, to: .now) ?? .now,
            authorUniversity: author.university,
            authorDepartment: author.department,
            authorYear: author.year,
            authorBio: author.bio,
            authorVerified: author.isVerified,
            authorBadge: author.badge,
            authorAvatarURL: author.imageAssetName.flatMap(UIImageAsset.fileURL(named:)),
            caption: caption,
            placeName: place,
            imageData: UIImageAsset.data(named: asset),
            createdAt: createdAt,
            comments: comments.map { name, body in
                BackendComment(id: UUID(), postID: postID, authorID: UUID(), authorName: name, body: body, createdAt: createdAt)
            },
            likeCount: likes,
            liked: liked,
            saved: false
        )
    }

    static func newPost(caption: String, placeName: String?, imageData: Data?) -> BackendPost {
        BackendPost(
            id: UUID(), authorID: me.id, authorName: me.name,
            authorBirthDate: Calendar.current.date(byAdding: .year, value: -me.age, to: .now) ?? .now,
            authorUniversity: me.university, authorDepartment: me.department, authorYear: me.year,
            authorBio: me.bio, authorVerified: me.isVerified, authorBadge: me.badge,
            authorAvatarURL: me.imageAssetName.flatMap(UIImageAsset.fileURL(named:)),
            caption: caption, placeName: placeName, imageData: imageData, createdAt: .now,
            comments: [], likeCount: 0, liked: false, saved: false
        )
    }

    static var notifications: [BackendNotification] {
        [
            BackendNotification(id: UUID(), kind: .match, title: "Yeni eşleşme",
                                body: "Ece ile denk geldiniz.", actorID: profiles[0].id, actorName: "Ece",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-ece"), matchID: nil, isRead: false, createdAt: hours(5.4)),
            BackendNotification(id: UUID(), kind: .message, title: "Yeni mesaj",
                                body: "Defne: Seni de bekleriz!", actorID: profiles[1].id, actorName: "Defne",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-defne"), matchID: nil, isRead: false, createdAt: hours(3)),
            BackendNotification(id: UUID(), kind: .like, title: "Gönderini beğendi",
                                body: "Selin sahil paylaşımını beğendi.", actorID: profiles[3].id, actorName: "Selin",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-selin"), matchID: nil, isRead: true, createdAt: hours(19)),
            BackendNotification(id: UUID(), kind: .comment, title: "Gönderine yorum",
                                body: "Ece: Kare çok iyi olmuş", actorID: profiles[0].id, actorName: "Ece",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-ece"), matchID: nil, isRead: true, createdAt: hours(19.5)),
            BackendNotification(id: UUID(), kind: .meetingRequest, title: "Buluşma isteği",
                                body: "Mina, Merkez Kütüphane'de buluşmak istiyor.", actorID: profiles[4].id, actorName: "Mina",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-mina"), matchID: nil, isRead: false, createdAt: date(1.2))
        ]
    }

    static func stories(places: [CampusPlace]) -> [CampusStory] {
        [
            CampusStory(author: me, imageAssetName: "post-campus", caption: "Sabah kampüsü",
                        place: places[0], viewed: false,
                        viewRecords: [
                            StoryViewRecord(viewer: profiles[0], viewCount: 2, lastViewedAt: hours(1)),
                            StoryViewRecord(viewer: profiles[4], viewCount: 1, lastViewedAt: hours(3))
                        ],
                        isMine: true),
            CampusStory(author: profiles[0], imageAssetName: "post-cafe", caption: "Bugünün ışığı",
                        place: places[1], viewed: false),
            CampusStory(author: profiles[4], imageAssetName: "post-study", caption: "Vize kampı 2. gün",
                        place: places[0], viewed: true)
        ]
    }

    static func clubs(places: [CampusPlace]) -> [CampusClub] {
        [
            CampusClub(id: id(30), name: "Fotoğraf Kulübü", summary: "Haftada bir kampüs turu, ayda bir sergi.",
                       icon: "camera.fill", memberCount: 128, nextEvent: "Gece çekimi — Perşembe 20.00",
                       meetingPlace: places[2], accentHex: "8066FF"),
            CampusClub(id: id(31), name: "Kitap Kulübü", summary: "Ayda bir kitap, sonunda uzun bir tartışma.",
                       icon: "book.fill", memberCount: 76, nextEvent: "Aylık toplantı — Salı 18.30",
                       meetingPlace: places[0], accentHex: "FF745E"),
            CampusClub(id: id(32), name: "Dağcılık ve Doğa", summary: "Hafta sonu rotaları, kamp ve tırmanış.",
                       icon: "figure.hiking", memberCount: 54, nextEvent: "Sahil yürüyüşü — Cumartesi 09.00",
                       meetingPlace: places[3], accentHex: "2E9E5B"),
            CampusClub(id: id(33), name: "Yazılım Topluluğu", summary: "Proje geceleri ve birlikte öğrenme.",
                       icon: "chevron.left.forwardslash.chevron.right", memberCount: 193, nextEvent: "Proje gecesi — Çarşamba 19.00",
                       meetingPlace: places[0], accentHex: "0F7FB8")
        ]
    }

    static func meetingRequests(places: [CampusPlace]) -> [MeetingRequest] {
        [
            MeetingRequest(profile: profiles[4], place: places[0], direction: .incoming, status: .pending, createdAt: date(1.2)),
            MeetingRequest(profile: profiles[1], place: places[1], direction: .outgoing, status: .accepted, createdAt: date(2.5)),
            MeetingRequest(profile: profiles[3], place: places[4], direction: .incoming, status: .declined, createdAt: date(4))
        ]
    }

    static var visits: [ProfileVisit] {
        [
            ProfileVisit(profile: profiles[0], visitedAt: hours(2)),
            ProfileVisit(profile: profiles[4], visitedAt: hours(9)),
            ProfileVisit(profile: profiles[2], visitedAt: date(1.5)),
            ProfileVisit(profile: profiles[3], visitedAt: date(4.2))
        ]
    }
}

/// Örnek görseller paketteki asset'lerden okunuyor.
///
/// `BackendPost` ham `Data` beklediği için gönderi görselleri JPEG'e çevriliyor.
/// Avatar tarafında ise model yalnızca `URL` taşıyor — asset adı taşımıyor — bu
/// yüzden görsel bir kez geçici dizine yazılıp `file://` adresi veriliyor.
/// Böylece örnek akış gerçek akışla aynı yolu (`AsyncImage`) kullanıyor.
private enum UIImageAsset {
    static func data(named: String) -> Data? {
        UIImage(named: named)?.jpegData(compressionQuality: 0.8)
    }

    private static let directory: URL = {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CampusSample", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func fileURL(named: String) -> URL? {
        let url = directory.appendingPathComponent("\(named).jpg")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let data = data(named: named) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

#endif
