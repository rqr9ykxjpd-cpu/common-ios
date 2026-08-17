import SwiftUI

@MainActor
@Observable
final class AppState {
    private enum SessionKey {
        static let isSignedIn = "session.isSignedIn"
        static let email = "session.email"
        static let accountEmail = "account.email"
        static let userID = "account.userID"
        static let profileDraft = "account.profileDraft"
        static let avatar = "account.avatar"
        static let gallery = "account.gallery"
    }

    enum Route: Equatable {
        case welcome
        case onboarding(OnboardingStep)
        case app
    }

    enum OnboardingStep: Int, Equatable, CaseIterable {
        case email, code, identity, preferences, interests, ready
    }

    var route: Route
    var email: String
    private(set) var currentUserID: UUID
    var verificationCode = ""
    var draft = ProfileDraft()
    var profiles: [StudentProfile] = StudentProfile.samples
    var conversations: [Conversation] = Conversation.samples
    var posts: [SocialPost] = SocialPost.samples.shuffled()
    var stories: [CampusStory] = CampusStory.samples.shuffled()
    var profileVisits: [ProfileVisit] = ProfileVisit.samples
    var notifications: [AppNotification] = AppNotification.samples
    var meetingRequests: [MeetingRequest] = []
    var avatarData: Data?
    var profileGalleryData: [Data] = []
    var currentMatch: StudentProfile?
    var selectedConversation: Conversation?
    var selectedStory: CampusStory?
    var selectedPlaceFilter: CampusPlace?
    var currentVisiblePlace: CampusPlace?
    var joinedClubIDs: Set<UUID> = []
    var toast: String?

    let service: any ProductService
    private let defaults: UserDefaults

    init(service: any ProductService = DemoProductService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        let hasSession = defaults.bool(forKey: SessionKey.isSignedIn)
        email = defaults.string(forKey: SessionKey.email) ?? defaults.string(forKey: SessionKey.accountEmail) ?? ""
        currentUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:)) ?? UUID()
        if let data = defaults.data(forKey: SessionKey.profileDraft),
           let savedDraft = try? JSONDecoder().decode(ProfileDraft.self, from: data) {
            draft = savedDraft
        }
        avatarData = defaults.data(forKey: SessionKey.avatar)
        if let data = defaults.data(forKey: SessionKey.gallery),
           let savedGallery = try? JSONDecoder().decode([Data].self, from: data) {
            profileGalleryData = savedGallery
        }
        route = hasSession ? .app : .welcome
        let incoming = MeetingRequest(profile: StudentProfile.samples[1], place: CampusPlace.samples[1], direction: .incoming, createdAt: .now.addingTimeInterval(-1_200))
        meetingRequests = [incoming]
        notifications.insert(AppNotification(kind: .meetingRequest, title: "Ece buluşmak istiyor", body: "Şamdan Kafe için gönderilen isteği yanıtla.", actor: incoming.profile, meetingRequestID: incoming.id, createdAt: incoming.createdAt), at: 0)
    }

    func beginOnboarding() {
        withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.email) }
    }

    func signIn(email: String, code: String) async {
        let username = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard username == "cem", code == "1283" else { return }
        try? await service.verifyOTP(email: username, code: code)
        self.email = username
        restoreOrCreateAccount(for: username)
        verificationCode = ""
        persistSession()
        withAnimation(.smooth(duration: 0.55)) { route = .app }
    }

    func advance(from step: OnboardingStep) {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            verificationCode = ""
            persistSession()
            withAnimation(.smooth(duration: 0.55)) { route = .app }
            return
        }
        withAnimation(.smooth(duration: 0.45)) { route = .onboarding(next) }
    }

    func goBack(from step: OnboardingStep) {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            withAnimation(.smooth(duration: 0.4)) { route = .onboarding(previous) }
        } else {
            withAnimation(.smooth(duration: 0.4)) { route = .welcome }
        }
    }

    func react(to profile: StudentProfile, liked: Bool) async {
        await service.recordReaction(profileID: profile.id, liked: liked)
        if liked, profile.name == "Ece" {
            currentMatch = profile
            notifications.insert(
                AppNotification(kind: .match, title: "Yeni bir eşleşme", body: "Sen ve Ece birbirinizi beğendiniz.", actor: profile),
                at: 0
            )
        }
        profiles.removeAll { $0.id == profile.id }
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].liked.toggle()
        posts[index].likeCount += posts[index].liked ? 1 : -1
        Haptics.impact(.light)
    }

    func publishPost(imageData: Data?, caption: String, place: CampusPlace?) {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageData != nil || !cleanCaption.isEmpty else { return }
        let author = currentUserProfile
        posts.insert(SocialPost(author: author, caption: cleanCaption, localImageData: imageData, place: place, isMine: true, likeCount: 0), at: 0)
        Haptics.success()
    }

    func publishStory(imageData: Data, caption: String, place: CampusPlace?) {
        stories.insert(CampusStory(author: currentUserProfile, localImageData: imageData, caption: caption, place: place, isMine: true), at: 0)
        if stories.count > 3 {
            stories.removeLast(stories.count - 3)
        }
        Haptics.success()
    }

    func toggleSaved(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].saved.toggle()
        Haptics.impact(.light)
    }

    func deletePost(_ postID: UUID) {
        guard posts.contains(where: { $0.id == postID && $0.isMine }) else { return }
        posts.removeAll { $0.id == postID }
        toast = "Gönderi silindi"
        Haptics.success()
    }

    func deleteStory(_ storyID: UUID) {
        guard stories.contains(where: { $0.id == storyID && $0.isMine }) else { return }
        stories.removeAll { $0.id == storyID }
        if selectedStory?.id == storyID { selectedStory = nil }
        toast = "Story silindi"
        Haptics.success()
    }

    func addComment(_ body: String, to postID: UUID) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty,
              let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].comments.append(SocialComment(author: currentUserProfile.name, body: cleanBody, isMine: true))
        Haptics.impact(.light)
    }

    func deleteComment(_ commentID: UUID, from postID: UUID) {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              posts[postIndex].comments.contains(where: { $0.id == commentID && $0.isMine }) else { return }
        posts[postIndex].comments.removeAll { $0.id == commentID }
        toast = "Yorum silindi"
        Haptics.success()
    }

    var currentUserPosts: [SocialPost] {
        posts.filter(\.isMine)
    }

    private var currentUserProfile: StudentProfile {
        StudentProfile(id: currentUserID, name: draft.name.isEmpty ? "Cem" : draft.name, age: draft.age, university: draft.university, department: draft.department.isEmpty ? "Öğrenci" : draft.department, year: draft.year, bio: draft.bio, interests: Array(draft.interests).sorted(), imageURL: nil, compatibility: 100, isVerified: true)
    }

    var profileCompletion: Int {
        let checks = [avatarData != nil, !draft.name.trimmed.isEmpty, !draft.department.trimmed.isEmpty, !draft.bio.trimmed.isEmpty, !draft.interests.isEmpty]
        return Int((Double(checks.filter { $0 }.count) / Double(checks.count)) * 100)
    }

    func saveProfile(_ updatedDraft: ProfileDraft, avatar: Data?, gallery: [Data]) {
        draft = updatedDraft
        avatarData = avatar
        profileGalleryData = gallery
        persistAccount()
        toast = "Profilin güncellendi"
        Haptics.success()
    }

    func markStoryViewed(_ story: CampusStory) {
        guard let storyIndex = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[storyIndex].viewed = true

        let viewer = currentUserProfile
        if let viewerIndex = stories[storyIndex].viewRecords.firstIndex(where: { $0.viewer.name == viewer.name }) {
            stories[storyIndex].viewRecords[viewerIndex].viewCount += 1
            stories[storyIndex].viewRecords[viewerIndex].lastViewedAt = .now
        } else {
            stories[storyIndex].viewRecords.append(StoryViewRecord(viewer: viewer, viewCount: 1))
        }
    }

    func meetingRequest(for profile: StudentProfile, at place: CampusPlace) -> MeetingRequest? {
        meetingRequests.first {
            $0.profile.id == profile.id && $0.place.id == place.id && $0.direction == .outgoing && $0.status == .pending
        }
    }

    func sendMeetingRequest(to profile: StudentProfile, at place: CampusPlace) {
        guard meetingRequest(for: profile, at: place) == nil else { return }
        meetingRequests.insert(MeetingRequest(profile: profile, place: place, direction: .outgoing), at: 0)
        toast = "\(profile.name) için \(place.name) buluşma isteği gönderildi"
        Haptics.success()
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) {
        guard let index = meetingRequests.firstIndex(where: { $0.id == requestID && $0.direction == .incoming && $0.status == .pending }) else { return }
        meetingRequests[index].status = accept ? .accepted : .declined
        notifications.removeAll { $0.meetingRequestID == requestID }
        toast = accept ? "Buluşma isteği kabul edildi" : "Buluşma isteği reddedildi"
        Haptics.success()
    }

    var pendingIncomingMeetingRequestCount: Int {
        meetingRequests.filter { $0.direction == .incoming && $0.status == .pending }.count
    }

    func togglePresence(at place: CampusPlace) {
        if currentVisiblePlace?.id == place.id {
            currentVisiblePlace = nil
            toast = "Yer görünürlüğün kapatıldı"
        } else {
            currentVisiblePlace = place
            toast = "Şu an \(place.name) konumunda görünürsün"
        }
        Haptics.success()
    }

    func isJoined(to club: CampusClub) -> Bool {
        joinedClubIDs.contains(club.id)
    }

    func toggleClubMembership(_ club: CampusClub) {
        if joinedClubIDs.contains(club.id) {
            joinedClubIDs.remove(club.id)
            toast = "\(club.name) üyeliğinden ayrıldın"
        } else {
            joinedClubIDs.insert(club.id)
            toast = "\(club.name) kulübüne katıldın"
        }
        Haptics.success()
    }

    func conversationID(for profile: StudentProfile) -> UUID {
        if let existing = conversations.first(where: { $0.profile.name == profile.name }) {
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

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        notifications[index].isRead = true
    }

    func markAllNotificationsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }

    func markConversationRead(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].unreadCount = 0
    }

    func send(_ body: String, in conversationID: UUID, replyTo: MessageReply? = nil) async {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let message = Message(body: cleanBody, isMine: true, sentAt: .now, replyTo: replyTo)
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        await service.send(message, conversationID: conversationID)
    }

    func react(to messageID: UUID, in conversationID: UUID, with reaction: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let current = conversations[conversationIndex].messages[messageIndex].reaction
        conversations[conversationIndex].messages[messageIndex].reaction = current == reaction ? nil : reaction
        Haptics.impact(.light)
    }

    func signOut() {
        persistAccount()
        defaults.set(false, forKey: SessionKey.isSignedIn)
        defaults.removeObject(forKey: SessionKey.email)
        verificationCode = ""
        currentMatch = nil
        selectedConversation = nil
        selectedStory = nil
        route = .welcome
    }

    func deleteAccount() {
        for key in [SessionKey.isSignedIn, SessionKey.email, SessionKey.accountEmail, SessionKey.userID, SessionKey.profileDraft, SessionKey.avatar, SessionKey.gallery] {
            defaults.removeObject(forKey: key)
        }
        email = ""
        currentUserID = UUID()
        verificationCode = ""
        draft = ProfileDraft()
        avatarData = nil
        profileGalleryData = []
        posts.removeAll { $0.isMine }
        stories.removeAll { $0.isMine }
        meetingRequests = []
        currentMatch = nil
        selectedConversation = nil
        selectedStory = nil
        selectedPlaceFilter = nil
        currentVisiblePlace = nil
        joinedClubIDs = []
        route = .welcome
        Haptics.success()
    }

    private func restoreOrCreateAccount(for signedInEmail: String) {
        if let savedUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:)) {
            currentUserID = savedUserID
        } else {
            currentUserID = UUID()
        }
        defaults.set(signedInEmail, forKey: SessionKey.accountEmail)
        if let data = defaults.data(forKey: SessionKey.profileDraft),
           let savedDraft = try? JSONDecoder().decode(ProfileDraft.self, from: data) {
            draft = savedDraft
        }
        avatarData = defaults.data(forKey: SessionKey.avatar)
        if let data = defaults.data(forKey: SessionKey.gallery),
           let savedGallery = try? JSONDecoder().decode([Data].self, from: data) {
            profileGalleryData = savedGallery
        }
    }

    private func persistAccount() {
        guard !email.isEmpty else { return }
        defaults.set(email.lowercased(), forKey: SessionKey.accountEmail)
        defaults.set(currentUserID.uuidString, forKey: SessionKey.userID)
        defaults.set(try? JSONEncoder().encode(draft), forKey: SessionKey.profileDraft)
        defaults.set(avatarData, forKey: SessionKey.avatar)
        defaults.set(try? JSONEncoder().encode(profileGalleryData), forKey: SessionKey.gallery)
    }

    private func persistSession() {
        defaults.set(true, forKey: SessionKey.isSignedIn)
        defaults.set(email, forKey: SessionKey.email)
        persistAccount()
    }
}

enum ProfileGender: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: Self { self }
    var title: String {
        switch self {
        case .female: "Kadın"
        case .male: "Erkek"
        }
    }
}

enum DatingPreference: String, Codable, CaseIterable, Identifiable {
    case women
    case men
    case everyone

    var id: Self { self }
    var title: String {
        switch self {
        case .women: "Kadınlar"
        case .men: "Erkekler"
        case .everyone: "Her ikisi"
        }
    }
}

struct ProfileDraft: Equatable, Codable {
    var name = ""
    var birthDate = Calendar.current.date(byAdding: .year, value: -21, to: .now) ?? .now
    var university = "YÜ"
    var department = ""
    var year = "3. sınıf"
    var bio = ""
    var interests: Set<String> = []
    var gender: ProfileGender?
    var datingPreference: DatingPreference?

    var age: Int {
        max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
