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
    var galleryPhotoCount: Int
    var studyGroups: [StudyGroup]

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
        self.galleryPhotoCount = SampleData.profiles[0].galleryImageURLs.count
        // Örnek: kütüphanede bir saat sonra başlayan, iki katılımlı grup.
        let host = SampleData.profiles[1]
        self.studyGroups = [
            StudyGroup(
                id: UUID(), host: host,
                place: places.first(where: { $0.name == "Merkez Kütüphane" }) ?? places[0],
                startsAt: Date().addingTimeInterval(3600), note: "Veri Yapıları vize tekrarı",
                capacity: 5, members: [SampleData.profiles[2], SampleData.profiles[3]],
                createdAt: Date().addingTimeInterval(-1200), isMine: false, joined: false
            )
        ]
    }

    // MARK: Çalışma grupları

    func allStudyGroups() -> [StudyGroup] {
        studyGroups.filter { $0.startsAt.addingTimeInterval(7200) > .now }.sorted { $0.startsAt < $1.startsAt }
    }

    func createStudyGroup(placeID: UUID, startsAt: Date, note: String, capacity: Int?) throws -> StudyGroup {
        if studyGroups.contains(where: { $0.isMine && $0.startsAt.addingTimeInterval(7200) > .now }) {
            throw NSError(domain: "Campus", code: 409, userInfo: [NSLocalizedDescriptionKey: "STUDY_GROUP_ACTIVE_EXISTS"])
        }
        guard let place = places.first(where: { $0.id == placeID }) else {
            throw NSError(domain: "Campus", code: 404, userInfo: [NSLocalizedDescriptionKey: "PLACE_NOT_FOUND"])
        }
        let group = StudyGroup(id: UUID(), host: me, place: place, startsAt: startsAt, note: note,
                               capacity: capacity, members: [], createdAt: .now, isMine: true, joined: false)
        studyGroups.insert(group, at: 0)
        return group
    }

    func cancelStudyGroup(_ id: UUID) { studyGroups.removeAll { $0.id == id } }

    func joinStudyGroup(_ id: UUID) throws {
        guard let i = studyGroups.firstIndex(where: { $0.id == id }) else { return }
        if studyGroups[i].isFull {
            throw NSError(domain: "Campus", code: 409, userInfo: [NSLocalizedDescriptionKey: "STUDY_GROUP_FULL"])
        }
        studyGroups[i].members.append(me)
        studyGroups[i].joined = true
    }

    func leaveStudyGroup(_ id: UUID) {
        guard let i = studyGroups.firstIndex(where: { $0.id == id }) else { return }
        studyGroups[i].members.removeAll { $0.id == me.id }
        studyGroups[i].joined = false
    }

    // MARK: Kampüs insanları

    func campusPeople(offset: Int, limit: Int) -> [StudentProfile] {
        let visible = profiles.filter { person in
            !blocked.contains(where: { $0.id == person.id })
            && !suspended.contains(person.id)
        }
        guard offset < visible.count else { return [] }
        return Array(visible[offset..<min(offset + limit, visible.count)])
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

    /// value: +1 / -1 / 0. Puan, eski oy düşülüp yenisi eklenerek güncellenir.
    func setPostVote(_ postID: UUID, value: Int) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let p = posts[index]
        let eski = p.liked ? 1 : (p.downvoted ? -1 : 0)
        posts[index] = p.copy(liked: value == 1, downvoted: value == -1, likeCount: p.likeCount - eski + value)
    }

    func setSaved(_ postID: UUID, saved: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index] = posts[index].copy(saved: saved)
    }

    func boost(_ postID: UUID, extra: Int) -> Int {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return 0 }
        let p = posts[index]
        let yeni = max(0, p.boost + extra)
        posts[index] = p.copy(likeCount: p.likeCount - p.boost + yeni, boost: yeni)
        return yeni
    }

    func boostComment(_ commentID: UUID, extra: Int) -> Int {
        for index in posts.indices {
            guard let ci = posts[index].comments.firstIndex(where: { $0.id == commentID }) else { continue }
            var comments = posts[index].comments
            let yeni = max(0, comments[ci].boost + extra)
            comments[ci].voteCount += yeni - comments[ci].boost
            comments[ci].boost = yeni
            posts[index] = posts[index].copy(comments: comments)
            return yeni
        }
        return 0
    }

    func setPin(_ postID: UUID, slot: Int?) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index] = posts[index].copy(pinnedAt: .some(slot == nil ? nil : Date()), pinnedSlot: .some(slot))
    }

    func setCommentVote(_ commentID: UUID, value: Int) {
        for index in posts.indices {
            guard let ci = posts[index].comments.firstIndex(where: { $0.id == commentID }) else { continue }
            var comments = posts[index].comments
            let eski = comments[ci].voted ? 1 : (comments[ci].downvoted ? -1 : 0)
            comments[ci].voted = value == 1
            comments[ci].downvoted = value == -1
            comments[ci].voteCount += value - eski
            posts[index] = posts[index].copy(comments: comments)
        }
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

    /// Demo: ilk yer kalabalık, sonrakiler seyrek, gerisi boş.
    func placePresence() -> [PlacePresenceSummary] {
        let profiles = SampleData.profiles
        let sirali = CampusPlaceOrder.sorted(places)
        var out: [PlacePresenceSummary] = []
        for (i, place) in sirali.enumerated() {
            let n = [4, 2, 1, 0, 3, 0, 1][i % 7]
            guard n > 0 else { continue }
            let kisiler = profiles.prefix(min(n, 3))
            out.append(PlacePresenceSummary(placeID: place.id, count: n, avatarURLs: [],
                                            avatarAssetNames: kisiler.compactMap(\.imageAssetName)))
        }
        return out
    }

    func allMeetingRequests() -> [MeetingRequest] { meetingRequests }

    // MARK: Moderasyon

    private var reports: [ModerationReport] = SampleData.reports
    private var suspended: Set<UUID> = []

    // MARK: Engellenenler

    private var blocked: [BlockedProfile] = SampleData.blockedProfiles
    private var rightSwipedIDs: Set<UUID> = []

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

    func addReport(profileID: UUID, reason: ReportReason, details: String?, target: ReportTarget? = nil,
                   contentText: String? = nil, mediaURL: URL? = nil) {
        guard profileID != me.id, let reported = profile(id: profileID) else { return }
        reports.insert(ModerationReport(
            id: UUID(), reporter: me, reported: reported, reason: reason, details: details,
            createdAt: .now, handledAt: nil, resolution: nil, reportedActive: true,
            target: target, contentText: contentText, contentMediaURL: mediaURL
        ), at: 0)
    }

    func addContentReport(_ target: ReportTarget, reason: ReportReason, details: String?) throws {
        switch target.kind {
        case .post:
            guard let post = posts.first(where: { $0.id == target.id }), post.authorID != me.id else {
                throw SampleReportError.unavailable
            }
            addReport(profileID: post.authorID, reason: reason, details: details, target: target,
                      contentText: post.caption, mediaURL: post.imageURL)
        case .story:
            guard let story = stories.first(where: { $0.id == target.id }), !story.isMine else {
                throw SampleReportError.unavailable
            }
            addReport(profileID: story.author.id, reason: reason, details: details, target: target,
                      contentText: story.caption)
        case .comment:
            guard let comment = posts.flatMap(\.comments).first(where: { $0.id == target.id }), comment.authorID != me.id else {
                throw SampleReportError.unavailable
            }
            addReport(profileID: comment.authorID, reason: reason, details: details, target: target,
                      contentText: comment.body)
        case .message:
            guard let conversation = conversations.first(where: { $0.messages.contains { $0.id == target.id && !$0.isMine } }),
                  let message = conversation.messages.first(where: { $0.id == target.id }) else {
                throw SampleReportError.unavailable
            }
            addReport(profileID: conversation.profile.id, reason: reason, details: details, target: target,
                      contentText: message.body)
        }
    }

    private enum SampleReportError: Error { case unavailable, missingTarget, alreadyResolved }

    func resolveReport(_ id: UUID, resolution: String) throws {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { throw SampleReportError.unavailable }
        if reports[index].handledAt != nil {
            guard reports[index].resolution == resolution else { throw SampleReportError.alreadyResolved }
            return
        }
        if resolution == ModerationReport.Resolution.contentRemoved.rawValue {
            guard let target = reports[index].target else { throw SampleReportError.missingTarget }
            switch target.kind {
            case .post: removePost(target.id)
            case .story: removeStory(target.id)
            case .comment: removeComment(target.id)
            case .message:
                for index in conversations.indices { conversations[index].messages.removeAll { $0.id == target.id } }
            }
        } else if resolution == ModerationReport.Resolution.accountSuspended.rawValue {
            setAccountActive(reports[index].reported.id, active: false)
        }
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

    func addRightSwipe(to profileID: UUID) throws -> RightSwipeOutcome {
        if profileID == me.id {
            throw NSError(domain: "Campus", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid swipe"])
        }
        if blocked.contains(where: { $0.id == profileID }) {
            throw NSError(domain: "Campus", code: 403, userInfo: [NSLocalizedDescriptionKey: "RIGHT_SWIPE_BLOCKED"])
        }
        // Ücretsiz plan: 2 günde 5 istek. Sunucudaki trigger ile aynı sayı.
        if rightSwipedIDs.count >= 5 {
            throw NSError(domain: "Campus", code: 429, userInfo: [NSLocalizedDescriptionKey: "QUOTA_CONNECTION_REQUEST"])
        }
        if !rightSwipedIDs.insert(profileID).inserted {
            throw NSError(domain: "Campus", code: 409, userInfo: [NSLocalizedDescriptionKey: "RIGHT_SWIPE_EXISTS"])
        }
        // Örnek veride Duru bize zaten istek göndermiş: sağa kaydırınca
        // karşılıklı olur ve "Bağlantı kuruldu" anı görülebilir. Gerçek akışta
        // bunu sunucu belirliyor.
        if let profile = profile(id: profileID), profile.name == "Duru" {
            let conversation = conversations.first(where: { $0.profile.id == profileID }) ?? {
                let yeni = Conversation(id: UUID(), profile: profile, messages: [], updatedAt: .now, unreadCount: 0)
                conversations.insert(yeni, at: 0)
                return yeni
            }()
            return RightSwipeOutcome(matched: true, matchID: conversation.id)
        }
        return RightSwipeOutcome(matched: false, matchID: nil)
    }

    /// Örnek veride kurucu "ben" olduğu için başka bir kurucu yoksa açılmaz.
    func openFounderChat() throws -> UUID {
        guard let kurucu = profiles.first(where: { $0.badge == .founder }) else {
            throw NSError(domain: "Campus", code: 404, userInfo: [NSLocalizedDescriptionKey: "FOUNDER_NOT_FOUND"])
        }
        if let mevcut = conversations.first(where: { $0.profile.id == kurucu.id }) { return mevcut.id }
        let yeni = Conversation(id: UUID(), profile: kurucu, messages: [], updatedAt: .now, unreadCount: 0)
        conversations.insert(yeni, at: 0)
        return yeni.id
    }

    // MARK: Profil

    func allVisits() -> [ProfileVisit] { visits }

    func myDraft() -> ProfileDraft { draft }

    func save(_ newDraft: ProfileDraft) { draft = newDraft }

    func replaceGalleryCount(_ count: Int) {
        galleryPhotoCount = min(count, CampusLimits.maxGalleryPhotos)
    }

    func appendGalleryPhoto() throws -> URL {
        guard galleryPhotoCount < CampusLimits.maxGalleryPhotos else {
            throw BackendServiceError.galleryFull
        }
        galleryPhotoCount += 1
        return URL(string: "https://sample.local/gallery/\(UUID().uuidString).jpg")!
    }
}

#endif
