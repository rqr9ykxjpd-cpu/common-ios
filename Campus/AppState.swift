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

        static func account(_ key: String, userID: UUID) -> String {
            "account.\(userID.uuidString.lowercased()).\(key)"
        }
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
    // Demo içeriği yalnızca `seedDemoContent()` üzerinden yüklenir; varsayılan durum her zaman boştur.
    var profiles: [StudentProfile] = []
    var discoveryFilters = DiscoveryFilters()
    var isLoadingDiscovery = false
    var isReactingToProfile = false
    var discoveryError: String?
    var lastPassedProfile: StudentProfile?
    var conversations: [Conversation] = []
    var posts: [SocialPost] = []
    var stories: [CampusStory] = []
    var profileVisits: [ProfileVisit] = []
    var notifications: [AppNotification] = []
    var meetingRequests: [MeetingRequest] = []
    /// Kampüs yerleri. Demo modunda örnek liste, backend modunda `places` tablosundan gelir —
    /// eskiden her yerde koda gömülü `CampusPlace.samples` kullanılıyordu.
    var places: [CampusPlace] = CampusPlace.samples
    /// Kulüpler. Demo modunda örnek liste, backend modunda `clubs` tablosundan gelir.
    var clubs: [CampusClub] = CampusClub.samples
    var avatarData: Data?
    var profileGalleryData: [Data] = []
    var avatarURL: URL?
    var galleryURLs: [URL] = []
    var currentMatch: StudentProfile?
    var selectedConversation: Conversation?
    var selectedStory: CampusStory?
    var selectedPlaceFilter: CampusPlace?
    var currentVisiblePlace: CampusPlace?
    var joinedClubIDs: Set<UUID> = []
    var isFinishingOnboarding = false
    var isAccountActionInProgress = false
    var toast: String?

    var isDemoAdmin: Bool {
        service.isDemo && email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "cem" && route == .app
    }

    let service: any ProductService
    private let defaults: UserDefaults
    private var messageListenerTask: Task<Void, Never>?

    init(service: (any ProductService)? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? ProductServiceFactory.make()
        self.defaults = defaults
        let hasSession = defaults.bool(forKey: SessionKey.isSignedIn)
        route = hasSession ? .app : .welcome
        email = defaults.string(forKey: SessionKey.email) ?? defaults.string(forKey: SessionKey.accountEmail) ?? ""
        currentUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:)) ?? UUID()
        loadAccountData(migratingLegacy: true)
        if self.service.isDemo { seedDemoContent() }
    }

    /// Örnek içeriği yükler. Yalnızca `DemoProductService` kullanılırken çağrılmalıdır —
    /// backend modunda bu verinin görünmesi gerçek kullanıcıya sahte profil ve bildirim gösterir.
    private func seedDemoContent() {
        assert(service.isDemo, "Demo içeriği yalnızca demo modunda yüklenmelidir")
        profiles = StudentProfile.samples
        conversations = Conversation.samples
        posts = SocialPost.samples.shuffled()
        stories = CampusStory.samples.shuffled()
        profileVisits = ProfileVisit.samples
        notifications = AppNotification.samples

        let incoming = MeetingRequest(
            profile: StudentProfile.samples[1],
            place: CampusPlace.samples[1],
            direction: .incoming,
            createdAt: .now.addingTimeInterval(-1_200)
        )
        meetingRequests = [incoming]
        notifications.insert(
            AppNotification(
                kind: .meetingRequest,
                title: "Ece buluşmak istiyor",
                body: "Şamdan Kafe için gönderilen isteği yanıtla.",
                actor: incoming.profile,
                meetingRequestID: incoming.id,
                createdAt: incoming.createdAt
            ),
            at: 0
        )
    }

    func beginOnboarding() {
        withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.email) }
    }

    func requestLoginCode(email: String) async -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard service.isDemo ? (normalized == "cem" || UniversityDomain.isValid(normalized)) : UniversityDomain.isValid(normalized) else {
            toast = service.isDemo ? "Demo için cem veya üniversite e-postası kullan" : "Yalnızca üniversite e-postası kullanılabilir"
            return false
        }
        do {
            try await service.requestOTP(email: normalized)
            self.email = normalized
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    func verifyOnboardingCode() async -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let valid = service.isDemo ? verificationCode == "1283" : verificationCode.count == 6
        guard valid else {
            toast = "Doğrulama kodunu kontrol et"
            return false
        }
        do {
            try await service.verifyOTP(email: normalized, code: verificationCode)
            currentUserID = service.currentUserID ?? currentUserID
            // Kayıt akışından gelen kullanıcının sunucuda profili olabilir (uygulamayı silip
            // yeniden kurmuş olabilir). Varsa yükleyip her şeyi baştan yazdırmıyoruz.
            if !service.isDemo, let profile = try? await service.fetchMyProfile() {
                applyRemoteProfile(profile)
            }
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    /// Kimlik doğrulama başarılıysa `true` döner. Giriş ekranı sonucu bekler; aksi halde
    /// hata durumunda ekran çoktan kapanmış oluyor ve kullanıcı yalnızca kaybolan bir
    /// bildirim görüyordu.
    @discardableResult
    func signIn(email: String, code: String) async -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard service.isDemo ? (normalized == "cem" && code == "1283") : (UniversityDomain.isValid(normalized) && code.count == 6) else {
            toast = "Giriş bilgilerini kontrol et"
            return false
        }
        do {
            try await service.verifyOTP(email: normalized, code: code)
            self.email = normalized
            currentUserID = service.currentUserID ?? currentUserID
            restoreOrCreateAccount(for: normalized)
            verificationCode = ""
            if service.isDemo {
                persistSession()
                seedDemoContent()
                withAnimation(.smooth(duration: 0.55)) { route = .app }
                return true
            }
            // Doğrulama başarılı olsa da sunucuda profil yoksa kullanıcı henüz kayıt akışını
            // tamamlamamış demektir. Doğrudan uygulamaya alırsak keşif sebepsiz boş gelir ve
            // nedenini anlamanın hiçbir yolu olmaz; onun yerine onboarding'e yönlendiriyoruz.
            // `persistSession` bilinçli olarak profil kontrolünden sonra çalışıyor: daha önce
            // OTP doğrulanır doğrulanmaz yazılıyordu ve bu adım hata verirse kullanıcı karşılama
            // ekranında kalmasına rağmen "giriş yapılmış" işaretleniyor, sonraki açılışta
            // doğrudan uygulamaya düşüyordu.
            let profile = try await service.fetchMyProfile()
            guard let profile else {
                persistSession()
                toast = "Profilini tamamlaman gerekiyor"
                withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.identity) }
                return true
            }
            applyRemoteProfile(profile)
            persistSession()
            await loadMyProfilePhotos()
            await loadNotifications()
            await loadPlaces()
            await loadStories()
            await loadClubs()
            await loadMeetingRequests()
            try? await service.touchLastActive()
            startMessageListener()
            withAnimation(.smooth(duration: 0.55)) { route = .app }
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    func restoreBackendSession() async {
        guard !service.isDemo else { return }
        do {
            guard let userID = try await service.restoreSession() else {
                // Sunucu oturumu bitmiş. Yerel bayrağı da düşürmezsek uygulama her açılışta
                // önce `.app`'e girip hemen geri atıyor.
                defaults.set(false, forKey: SessionKey.isSignedIn)
                if route == .app { route = .welcome }
                return
            }
            currentUserID = userID
            // Uygulama silinip yeniden kurulduğunda yerel kayıt sıfırlanır ama Supabase oturumu
            // Keychain'de kaldığı için hâlâ geçerlidir. E-postayı oturumdan geri almazsak
            // `persistSession` boş e-posta yüzünden hiçbir şey yazmaz ve kullanıcı geçerli bir
            // oturumla karşılama ekranında mahsur kalır.
            if email.isEmpty, let sessionEmail = service.currentUserEmail {
                email = sessionEmail.lowercased()
            }

            let profile = try await service.fetchMyProfile()
            guard let profile else {
                // Oturum var ama profil yok: kayıt akışı yarıda kalmış.
                toast = "Profilini tamamlaman gerekiyor"
                withAnimation(.smooth(duration: 0.45)) { route = .onboarding(.identity) }
                return
            }
            applyRemoteProfile(profile)
            if !email.isEmpty { persistSession() }
            await loadMyProfilePhotos()
            await loadNotifications()
            await loadPlaces()
            await loadStories()
            await loadClubs()
            await loadMeetingRequests()
            try? await service.touchLastActive()
            startMessageListener()
            // Geçerli oturum ve tamamlanmış profil varken karşılama ekranında bırakmak
            // kullanıcıyı hiçbir yere gidemez halde bırakıyordu.
            if route != .app {
                withAnimation(.smooth(duration: 0.45)) { route = .app }
            }
        } catch {
            route = .welcome
            toast = error.localizedDescription
        }
    }

    /// Sunucudaki profili yerel duruma yazar. `draft` yalnızca UserDefaults'tan geldiği için
    /// kullanıcı başka bir cihazdan girdiğinde profili sunucuda dururken boş görünüyordu.
    private func applyRemoteProfile(_ profile: ProfileDraft) {
        draft = profile
        discoveryFilters = profile.discoveryFilters
        persistAccount()
    }

    private func loadMyProfilePhotos() async {
        guard !service.isDemo else { return }
        if let result = try? await service.fetchMyProfilePhotos() {
            avatarURL = result.avatarURL
            galleryURLs = result.galleryURLs
        }
    }

    /// Sohbet ekranı açık olmasa da eşleşmelerdeki yeni mesajları anlık yakalar —
    /// aksi halde `ConversationView` yalnızca açılış anında bir kerelik yüklüyor,
    /// karşı taraf yazınca ekranda görünmüyor.
    private func startMessageListener() {
        guard !service.isDemo, messageListenerTask == nil else { return }
        messageListenerTask = Task { [weak self] in
            guard let self else { return }
            for await payload in self.service.messageStream() {
                self.handleIncomingMessage(payload)
            }
        }
    }

    private func stopMessageListener() {
        messageListenerTask?.cancel()
        messageListenerTask = nil
    }

    private func handleIncomingMessage(_ payload: RealtimeMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == payload.matchID }) else {
            // Bilinmeyen bir eşleşmenin ilk mesajı olabilir; sohbet listesini tazele.
            Task { await loadConversations() }
            return
        }
        guard !conversations[index].messages.contains(where: { $0.id == payload.id }) else { return }
        let peerName = conversations[index].profile.name
        let replyTo = payload.replyToID.flatMap { replyID in
            conversations[index].messages.first(where: { $0.id == replyID }).map {
                MessageReply(messageID: $0.id, authorName: $0.isMine ? "Sen" : peerName, body: $0.body)
            }
        }
        let isMine = payload.senderID == currentUserID
        let message = Message(id: payload.id, body: payload.body, isMine: isMine, sentAt: payload.createdAt, reaction: payload.reaction, replyTo: replyTo)
        conversations[index].messages.append(message)
        conversations[index].updatedAt = message.sentAt
        if !isMine {
            conversations[index].unreadCount += 1
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    func advance(from step: OnboardingStep) {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            Task { await finishOnboarding() }
            return
        }
        withAnimation(.smooth(duration: 0.45)) { route = .onboarding(next) }
    }

    /// Onboarding'in son adımı. Profili sunucuya kaydeder ve **yalnızca kayıt başarılıysa**
    /// uygulamaya geçer. Aksi halde kullanıcı profilsiz şekilde içeri girer, keşif sebepsiz
    /// boş gelir ve durumun neden böyle olduğu anlaşılmaz.
    private func finishOnboarding() async {
        guard !isFinishingOnboarding else { return }
        isFinishingOnboarding = true
        defer { isFinishingOnboarding = false }
        do {
            try await service.saveProfile(draft)
        } catch {
            toast = error.localizedDescription
            return
        }
        verificationCode = ""
        persistSession()
        // Kayıt akışıyla giren kullanıcı da anlık mesajları almalı; bunlar yalnızca `signIn` ve
        // `restoreBackendSession` içinde kuruluyordu, yeni kullanıcı uygulamayı yeniden
        // başlatana kadar gelen mesajları görmüyordu.
        if !service.isDemo {
            await loadMyProfilePhotos()
            await loadNotifications()
            await loadPlaces()
            await loadStories()
            await loadClubs()
            await loadMeetingRequests()
            try? await service.touchLastActive()
            startMessageListener()
        }
        withAnimation(.smooth(duration: 0.55)) { route = .app }
    }

    func goBack(from step: OnboardingStep) {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) {
            withAnimation(.smooth(duration: 0.4)) { route = .onboarding(previous) }
        } else {
            withAnimation(.smooth(duration: 0.4)) { route = .welcome }
        }
    }

    func loadDiscovery(reset: Bool = false) async {
        guard !isLoadingDiscovery else { return }
        isLoadingDiscovery = true
        discoveryError = nil
        defer { isLoadingDiscovery = false }
        do {
            let offset = reset ? 0 : profiles.count
            let candidates = try await service.fetchDiscoveryCandidates(filters: discoveryFilters, offset: offset, limit: 20)
            if reset { profiles = candidates } else {
                let existing = Set(profiles.map(\.id))
                profiles.append(contentsOf: candidates.filter { !existing.contains($0.id) })
            }
        } catch {
            discoveryError = error.localizedDescription
        }
    }

    func applyDiscoveryFilters(_ filters: DiscoveryFilters) async {
        discoveryFilters = filters
        await loadDiscovery(reset: true)
    }

    func react(to profile: StudentProfile, liked: Bool) async {
        guard !isReactingToProfile else { return }
        isReactingToProfile = true
        discoveryError = nil
        defer { isReactingToProfile = false }
        do {
            let result = try await service.reactToProfile(profileID: profile.id, liked: liked)
            profiles.removeAll { $0.id == profile.id }
            lastPassedProfile = liked ? nil : profile
            if result.matched, let matchID = result.matchID {
                currentMatch = profile
                _ = conversationID(for: profile, matchID: matchID)
                // Backend modunda eşleşme bildirimini veritabanı trigger'ı üretiyor; burada
                // ayrıca eklersek aynı bildirim iki kez görünür.
                if service.isDemo {
                    notifications.insert(
                        AppNotification(kind: .match, title: "Yeni bir eşleşme", body: "Sen ve \(profile.name) birbirinizi beğendiniz.", actor: profile),
                        at: 0
                    )
                }
            }
            if profiles.count < 3, !service.isDemo { await loadDiscovery() }
        } catch {
            discoveryError = error.localizedDescription
        }
    }

    func undoLastPass() {
        guard service.isDemo, let profile = lastPassedProfile else {
            toast = "Geri alma yalnızca gönderilmemiş demo kararında kullanılabilir"
            return
        }
        profiles.insert(profile, at: 0)
        lastPassedProfile = nil
        Haptics.impact(.light)
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let newLiked = !posts[index].liked
        posts[index].liked = newLiked
        posts[index].likeCount += newLiked ? 1 : -1
        Haptics.impact(.light)
        guard !service.isDemo else { return }
        Task {
            do {
                try await service.setPostLiked(postID, liked: newLiked)
            } catch {
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].liked = !newLiked
                posts[refreshedIndex].likeCount += newLiked ? -1 : 1
                toast = error.localizedDescription
            }
        }
    }

    func loadFeed() async {
        guard !service.isDemo else { return }
        do {
            posts = try await service.fetchFeed().map(socialPost(from:))
        } catch {
            toast = error.localizedDescription
        }
    }

    func publishPost(imageData: Data?, caption: String, place: CampusPlace?) {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageData != nil || !cleanCaption.isEmpty else { return }
        if service.isDemo {
            let author = currentUserProfile
            posts.insert(SocialPost(author: author, caption: cleanCaption, localImageData: imageData, place: place, isMine: true, likeCount: 0), at: 0)
            Haptics.success()
            return
        }
        Task {
            do {
                let post = try await service.createPost(caption: cleanCaption, placeName: place?.name, imageData: imageData)
                posts.insert(socialPost(from: post), at: 0)
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    /// Story'leri sunucudan yükler. Bu liste akışın en üstünde duruyor ama şimdiye kadar
    /// yalnızca bellekteydi; uygulama kapanınca paylaşılan story kayboluyordu.
    func loadStories() async {
        guard !service.isDemo else { return }
        do {
            stories = try await service.fetchStories()
        } catch {
            toast = error.localizedDescription
        }
    }

    func publishStory(imageData: Data, caption: String, place: CampusPlace?) {
        if service.isDemo {
            stories.insert(CampusStory(author: currentUserProfile, localImageData: imageData, caption: caption, place: place, isMine: true), at: 0)
            if stories.count > 3 { stories.removeLast(stories.count - 3) }
            Haptics.success()
            return
        }
        Task {
            do {
                try await service.publishStory(imageData: imageData, caption: caption, placeID: place?.id)
                await loadStories()
            await loadClubs()
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    func toggleSaved(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].saved.toggle()
        Haptics.impact(.light)
    }

    func deletePost(_ postID: UUID) {
        guard posts.contains(where: { $0.id == postID && ($0.isMine || isDemoAdmin) }) else { return }
        if service.isDemo {
            posts.removeAll { $0.id == postID }
            toast = "Gönderi silindi"
            Haptics.success()
            return
        }
        Task {
            do {
                try await service.deletePost(postID)
                posts.removeAll { $0.id == postID }
                toast = "Gönderi silindi"
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    func deleteStory(_ storyID: UUID) {
        guard let removed = stories.first(where: { $0.id == storyID && $0.isMine }) else { return }
        stories.removeAll { $0.id == storyID }
        if selectedStory?.id == storyID { selectedStory = nil }
        toast = "Story silindi"
        Haptics.success()
        guard !service.isDemo else { return }
        Task {
            do { try await service.deleteStory(storyID) }
            catch {
                stories.insert(removed, at: 0)
                toast = error.localizedDescription
            }
        }
    }

    func addComment(_ body: String, to postID: UUID) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty,
              let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        if service.isDemo {
            posts[index].comments.append(SocialComment(author: currentUserProfile.name, body: cleanBody, isMine: true))
            Haptics.impact(.light)
            return
        }
        Task {
            do {
                let comment = try await service.addComment(cleanBody, to: postID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.append(socialComment(from: comment))
                Haptics.impact(.light)
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    func deleteComment(_ commentID: UUID, from postID: UUID) {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              posts[postIndex].comments.contains(where: { $0.id == commentID && ($0.isMine || isDemoAdmin) }) else { return }
        if service.isDemo {
            posts[postIndex].comments.removeAll { $0.id == commentID }
            toast = "Yorum silindi"
            Haptics.success()
            return
        }
        Task {
            do {
                try await service.deleteComment(commentID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.removeAll { $0.id == commentID }
                toast = "Yorum silindi"
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    func moderateDemoProfile(_ profile: StudentProfile, block: Bool) {
        guard isDemoAdmin else { return }
        if block {
            profiles.removeAll { $0.id == profile.id }
            posts.removeAll { $0.author.id == profile.id }
            stories.removeAll { $0.author.id == profile.id }
            conversations.removeAll { $0.profile.id == profile.id }
            notifications.removeAll { $0.actor?.id == profile.id }
            toast = "\(profile.name) demo akışından engellendi"
        } else {
            toast = "\(profile.name) için demo şikâyeti incelemeye alındı"
        }
        Haptics.success()
    }

    func block(_ profile: StudentProfile) {
        if service.isDemo {
            moderateDemoProfile(profile, block: true)
            return
        }
        Task {
            do {
                try await service.blockUser(profile.id)
                profiles.removeAll { $0.id == profile.id }
                conversations.removeAll { $0.profile.id == profile.id }
                posts.removeAll { $0.author.id == profile.id }
                notifications.removeAll { $0.actor?.id == profile.id }
                if selectedConversation?.profile.id == profile.id { selectedConversation = nil }
                toast = "\(profile.name) engellendi"
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    func report(_ profile: StudentProfile, reason: ReportReason) {
        if service.isDemo {
            moderateDemoProfile(profile, block: false)
            return
        }
        Task {
            do {
                try await service.reportUser(profile.id, reason: reason, details: nil)
                toast = "Şikâyetin alındı, incelenecek"
                Haptics.success()
            } catch {
                toast = error.localizedDescription
            }
        }
    }

    var currentUserPosts: [SocialPost] {
        posts.filter(\.isMine)
    }

    var currentUserProfile: StudentProfile {
        StudentProfile(id: currentUserID, name: draft.name.isEmpty ? "Cem" : draft.name, age: draft.age, university: draft.university, department: draft.department.isEmpty ? "Öğrenci" : draft.department, year: draft.year, bio: draft.bio, interests: Array(draft.interests).sorted(), imageURL: avatarURL, compatibility: 100, isVerified: true)
    }

    /// Keşifte başkalarının gördüğü haliyle kendi kartın. Uyum yüzdesi ve nedenleri karşı tarafa
    /// göre hesaplandığı için burada gösterilmez; geri kalan her alan gerçek profilden gelir.
    var ownDiscoveryCardPreview: StudentProfile {
        StudentProfile(
            id: currentUserID,
            name: draft.name.isEmpty ? "Adın" : draft.name,
            age: draft.age,
            university: draft.university,
            department: draft.department.isEmpty ? "Bölümün" : draft.department,
            year: draft.year,
            bio: draft.bio.isEmpty ? "Hakkımda bölümü boş — profilini tamamlayınca burası dolacak." : draft.bio,
            interests: Array(draft.interests).sorted(),
            imageURL: avatarURL,
            galleryImageURLs: galleryURLs,
            compatibility: 0,
            isVerified: true,
            compatibilityReasons: [],
            prompts: draft.prompts,
            relationshipIntent: draft.relationshipIntent,
            activeLabel: "Yakın zamanda aktif"
        )
    }

    var profileCompletion: Int {
        let checks = [avatarData != nil || avatarURL != nil, !draft.name.trimmed.isEmpty, !draft.department.trimmed.isEmpty, !draft.bio.trimmed.isEmpty, !draft.interests.isEmpty]
        return Int((Double(checks.filter { $0 }.count) / Double(checks.count)) * 100)
    }

    func saveProfile(_ updatedDraft: ProfileDraft, avatar: Data?, gallery: [Data]) async -> Bool {
        do {
            try await service.saveProfile(updatedDraft)
            draft = updatedDraft
            avatarData = avatar
            profileGalleryData = gallery
            discoveryFilters = updatedDraft.discoveryFilters
            if !service.isDemo {
                avatarURL = try await service.updateAvatar(avatar)
                galleryURLs = try await service.updateGallery(gallery)
            }
            persistAccount()
            toast = "Profilin güncellendi"
            Haptics.success()
            return true
        } catch {
            toast = error.localizedDescription
            return false
        }
    }

    func markStoryViewed(_ story: CampusStory) {
        guard let storyIndex = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[storyIndex].viewed = true

        if service.isDemo {
            let viewer = currentUserProfile
            if let viewerIndex = stories[storyIndex].viewRecords.firstIndex(where: { $0.viewer.name == viewer.name }) {
                stories[storyIndex].viewRecords[viewerIndex].viewCount += 1
                stories[storyIndex].viewRecords[viewerIndex].lastViewedAt = .now
            } else {
                stories[storyIndex].viewRecords.append(StoryViewRecord(viewer: viewer, viewCount: 1))
            }
            return
        }
        let storyID = story.id
        let isMine = story.isMine
        Task {
            try? await service.markStoryViewed(storyID)
            // İzleyen listesini yalnızca story sahibi görebilir; başkasının story'sinde
            // bu sorgu boş döneceği için hiç yapmıyoruz.
            guard isMine, let records = try? await service.fetchStoryViews(storyID),
                  let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
            stories[index].viewRecords = records
        }
    }

    func meetingRequest(for profile: StudentProfile, at place: CampusPlace) -> MeetingRequest? {
        meetingRequests.first {
            $0.profile.id == profile.id && $0.place.id == place.id && $0.direction == .outgoing && $0.status == .pending
        }
    }

    /// Buluşma isteklerini sunucudan yükler. Bu liste şimdiye kadar yalnızca bellekte
    /// yaşıyordu; uygulama kapanınca gönderilen ve gelen istekler kayboluyordu.
    func loadMeetingRequests() async {
        guard !service.isDemo else { return }
        do {
            meetingRequests = try await service.fetchMeetingRequests()
        } catch {
            toast = error.localizedDescription
        }
    }

    func loadPlaces() async {
        guard !service.isDemo else { return }
        if let loaded = try? await service.fetchPlaces(), !loaded.isEmpty {
            places = loaded
        }
    }

    func sendMeetingRequest(to profile: StudentProfile, at place: CampusPlace) {
        guard meetingRequest(for: profile, at: place) == nil else { return }
        if service.isDemo {
            meetingRequests.insert(MeetingRequest(profile: profile, place: place, direction: .outgoing), at: 0)
            toast = "\(profile.name) için \(place.name) buluşma isteği gönderildi"
            Haptics.success()
            return
        }
        let optimistic = MeetingRequest(profile: profile, place: place, direction: .outgoing)
        meetingRequests.insert(optimistic, at: 0)
        Task {
            do {
                try await service.sendMeetingRequest(to: profile.id, placeID: place.id)
                await loadMeetingRequests()
                toast = "\(profile.name) için \(place.name) buluşma isteği gönderildi"
                Haptics.success()
            } catch {
                meetingRequests.removeAll { $0.id == optimistic.id }
                toast = error.localizedDescription
            }
        }
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) {
        guard let index = meetingRequests.firstIndex(where: { $0.id == requestID && $0.direction == .incoming && $0.status == .pending }) else { return }
        let previous = meetingRequests[index].status
        meetingRequests[index].status = accept ? .accepted : .declined
        notifications.removeAll { $0.meetingRequestID == requestID }
        toast = accept ? "Buluşma isteği kabul edildi" : "Buluşma isteği reddedildi"
        Haptics.success()
        guard !service.isDemo else { return }
        Task {
            do {
                try await service.respondToMeetingRequest(requestID, accept: accept)
            } catch {
                if let refreshed = meetingRequests.firstIndex(where: { $0.id == requestID }) {
                    meetingRequests[refreshed].status = previous
                }
                toast = error.localizedDescription
            }
        }
    }

    var pendingIncomingMeetingRequestCount: Int {
        meetingRequests.filter { $0.direction == .incoming && $0.status == .pending }.count
    }

    func togglePresence(at place: CampusPlace) {
        let previous = currentVisiblePlace
        let turningOff = currentVisiblePlace?.id == place.id
        currentVisiblePlace = turningOff ? nil : place
        toast = turningOff ? "Yer görünürlüğün kapatıldı" : "Şu an \(place.name) konumunda görünürsün"
        Haptics.success()
        guard !service.isDemo else { return }
        Task {
            do {
                try await service.setVisiblePlace(turningOff ? nil : place.id)
            } catch {
                currentVisiblePlace = previous
                toast = error.localizedDescription
            }
        }
    }

    /// Bir yerde şu an görünen kişiler. Bu liste koda gömülü sabit isimlerdi; herkese
    /// aynı sahte kişiler gösteriliyordu.
    func peopleAtPlace(_ place: CampusPlace) async -> [StudentProfile] {
        guard !service.isDemo else { return place.activeProfiles }
        return (try? await service.fetchPeopleAtPlace(place.id)) ?? []
    }

    func isJoined(to club: CampusClub) -> Bool {
        joinedClubIDs.contains(club.id)
    }

    /// Kulüpleri ve üyeliklerini sunucudan yükler. Liste eskiden koda gömülüydü ve
    /// katılma bilgisi yalnızca bellekte tutulduğu için uygulama kapanınca kayboluyordu.
    func loadClubs() async {
        guard !service.isDemo else { return }
        if let result = try? await service.fetchClubs() {
            clubs = result.clubs
            joinedClubIDs = result.joinedIDs
        }
    }

    func toggleClubMembership(_ club: CampusClub) {
        let willJoin = !joinedClubIDs.contains(club.id)
        if willJoin {
            joinedClubIDs.insert(club.id)
            toast = "\(club.name) kulübüne katıldın"
        } else {
            joinedClubIDs.remove(club.id)
            toast = "\(club.name) üyeliğinden ayrıldın"
        }
        Haptics.success()
        guard !service.isDemo else { return }
        Task {
            do {
                try await service.setClubMembership(club.id, joined: willJoin)
                await loadClubs()
            } catch {
                if willJoin { joinedClubIDs.remove(club.id) } else { joinedClubIDs.insert(club.id) }
                toast = error.localizedDescription
            }
        }
    }

    func loadConversations() async {
        do {
            conversations = try await service.fetchConversations()
        } catch {
            discoveryError = error.localizedDescription
        }
    }

    func conversationID(for profile: StudentProfile, matchID: UUID? = nil) -> UUID {
        if let existing = conversations.first(where: { $0.profile.id == profile.id }) {
            return existing.id
        }
        let conversation = Conversation(
            id: matchID ?? UUID(),
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

    /// Bildirimleri sunucudan yükler. Bu ekran şimdiye kadar yalnızca demo örneklerinden
    /// besleniyordu; gerçek kullanıcı eşleşme veya mesaj aldığında hiçbir şey görmüyordu.
    func loadNotifications() async {
        guard !service.isDemo else { return }
        do {
            notifications = try await service.fetchNotifications().map(appNotification(from:))
        } catch {
            toast = error.localizedDescription
        }
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }), !notifications[index].isRead else { return }
        notifications[index].isRead = true
        guard !service.isDemo else { return }
        Task {
            do { try await service.markNotificationRead(notificationID) }
            catch {
                if let refreshed = notifications.firstIndex(where: { $0.id == notificationID }) {
                    notifications[refreshed].isRead = false
                }
                toast = error.localizedDescription
            }
        }
    }

    func markAllNotificationsRead() {
        let previous = notifications
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        guard !service.isDemo else { return }
        Task {
            do { try await service.markAllNotificationsRead() }
            catch {
                notifications = previous
                toast = error.localizedDescription
            }
        }
    }

    private func appNotification(from backend: BackendNotification) -> AppNotification {
        let actor = backend.actorID.map { actorID in
            StudentProfile(
                id: actorID,
                name: backend.actorName ?? "Biri",
                age: 18,
                university: draft.university,
                department: "",
                year: "",
                bio: "",
                interests: [],
                imageURL: backend.actorAvatarURL,
                compatibility: 0,
                isVerified: true
            )
        }
        return AppNotification(
            id: backend.id,
            kind: backend.kind,
            title: backend.title,
            body: backend.body,
            actor: actor,
            createdAt: backend.createdAt,
            isRead: backend.isRead
        )
    }

    func markConversationRead(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].unreadCount = 0
        Task {
            do { try await service.markConversationRead(matchID: conversationID) }
            catch { discoveryError = error.localizedDescription }
        }
    }

    func send(_ body: String, in conversationID: UUID, replyTo: MessageReply? = nil) async {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let message = Message(body: cleanBody, isMine: true, sentAt: .now, replyTo: replyTo)
        conversations[index].messages.append(message)
        conversations[index].updatedAt = .now
        do {
            let saved = try await service.sendMessage(message, matchID: conversationID)
            guard let refreshedIndex = conversations.firstIndex(where: { $0.id == conversationID }),
                  let messageIndex = conversations[refreshedIndex].messages.firstIndex(where: { $0.id == message.id }) else { return }
            conversations[refreshedIndex].messages[messageIndex] = saved
        } catch {
            if let refreshedIndex = conversations.firstIndex(where: { $0.id == conversationID }) {
                conversations[refreshedIndex].messages.removeAll { $0.id == message.id }
            }
            discoveryError = error.localizedDescription
            toast = "Mesaj gönderilemedi"
        }
    }

    func react(to messageID: UUID, in conversationID: UUID, with reaction: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let previous = conversations[conversationIndex].messages[messageIndex].reaction
        let updated = previous == reaction ? nil : reaction
        conversations[conversationIndex].messages[messageIndex].reaction = updated
        Task {
            do {
                try await service.setMessageReaction(messageID: messageID, reaction: updated)
                Haptics.impact(.light)
            } catch {
                guard let refreshedConversation = conversations.firstIndex(where: { $0.id == conversationID }),
                      let refreshedMessage = conversations[refreshedConversation].messages.firstIndex(where: { $0.id == messageID }) else { return }
                conversations[refreshedConversation].messages[refreshedMessage].reaction = previous
                toast = error.localizedDescription
            }
        }
    }

    func signOut() async {
        guard !isAccountActionInProgress else { return }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        persistAccount()
        do {
            try await service.signOut()
            clearSession(keepAccountData: true)
        } catch {
            toast = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard !isAccountActionInProgress else { return }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        do {
            try await service.deleteAccount()
            clearSession(keepAccountData: false)
        } catch {
            toast = error.localizedDescription
        }
    }

    private func clearSession(keepAccountData: Bool) {
        stopMessageListener()
        let accountID = currentUserID
        if !keepAccountData {
            for key in ["email", "profileDraft", "avatar", "gallery"] {
                defaults.removeObject(forKey: SessionKey.account(key, userID: accountID))
            }
            for legacyKey in [SessionKey.accountEmail, SessionKey.profileDraft, SessionKey.avatar, SessionKey.gallery] {
                defaults.removeObject(forKey: legacyKey)
            }
        }
        defaults.set(false, forKey: SessionKey.isSignedIn)
        defaults.removeObject(forKey: SessionKey.email)
        defaults.removeObject(forKey: SessionKey.userID)
        email = ""
        currentUserID = UUID()
        verificationCode = ""
        draft = ProfileDraft()
        discoveryFilters = DiscoveryFilters()
        avatarData = nil
        profileGalleryData = []
        avatarURL = nil
        galleryURLs = []
        profiles = []
        conversations = []
        posts = []
        stories = []
        profileVisits = []
        notifications = []
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
        if service.isDemo {
            let stableDemoID = UUID(uuidString: "00000000-0000-0000-0000-000000001283")!
            currentUserID = signedInEmail == "cem" ? stableDemoID : UUID()
        } else if let backendUserID = service.currentUserID {
            currentUserID = backendUserID
        }
        defaults.set(signedInEmail, forKey: SessionKey.account("email", userID: currentUserID))
        loadAccountData(migratingLegacy: true)
    }

    private func loadAccountData(migratingLegacy: Bool) {
        let draftKey = SessionKey.account("profileDraft", userID: currentUserID)
        let avatarKey = SessionKey.account("avatar", userID: currentUserID)
        let galleryKey = SessionKey.account("gallery", userID: currentUserID)
        let legacyUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:))
        let canMigrateLegacy = migratingLegacy && legacyUserID == currentUserID
        let storedDraft = defaults.data(forKey: draftKey) ?? (canMigrateLegacy ? defaults.data(forKey: SessionKey.profileDraft) : nil)
        if let storedDraft, let savedDraft = try? JSONDecoder().decode(ProfileDraft.self, from: storedDraft) { draft = savedDraft }
        discoveryFilters = draft.discoveryFilters
        // Avatar/galeri artık Supabase Storage'da yaşıyor (bkz. loadMyProfilePhotos), UserDefaults
        // ham görsel verisi için tasarlanmadığından burada yalnızca eski kayıtları temizliyoruz.
        defaults.removeObject(forKey: avatarKey)
        defaults.removeObject(forKey: galleryKey)
        if canMigrateLegacy, defaults.data(forKey: draftKey) == nil { persistAccount() }
    }

    private func persistAccount() {
        guard !email.isEmpty else { return }
        defaults.set(currentUserID.uuidString, forKey: SessionKey.userID)
        defaults.set(email.lowercased(), forKey: SessionKey.account("email", userID: currentUserID))
        defaults.set(try? JSONEncoder().encode(draft), forKey: SessionKey.account("profileDraft", userID: currentUserID))
    }

    private func socialPost(from post: BackendPost) -> SocialPost {
        let age = max(18, Calendar.current.dateComponents([.year], from: post.authorBirthDate, to: .now).year ?? 18)
        let author = StudentProfile(
            id: post.authorID,
            name: post.authorName,
            age: age,
            university: post.authorUniversity,
            department: post.authorDepartment,
            year: post.authorYear,
            bio: post.authorBio,
            interests: [],
            imageURL: post.authorAvatarURL,
            compatibility: 0,
            isVerified: post.authorVerified
        )
        return SocialPost(
            id: post.id,
            author: author,
            caption: post.caption,
            localImageData: post.imageData,
            place: post.placeName.flatMap { name in CampusPlace.samples.first { $0.name == name } },
            liked: post.liked,
            isMine: post.authorID == currentUserID,
            likeCount: post.likeCount,
            comments: post.comments.map(socialComment(from:)),
            createdAt: post.createdAt
        )
    }

    private func socialComment(from comment: BackendComment) -> SocialComment {
        SocialComment(
            id: comment.id,
            author: comment.authorName,
            body: comment.body,
            isMine: comment.authorID == currentUserID,
            createdAt: comment.createdAt
        )
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
    var relationshipIntent: RelationshipIntent = .both
    var prompts: [ProfilePrompt] = Self.defaultPrompts
    var discoveryFilters = DiscoveryFilters()

    private static var defaultPrompts: [ProfilePrompt] {
        [
            ProfilePrompt(question: "Kampüste beni nerede bulursun?", answer: ""),
            ProfilePrompt(question: "İlk buluşma fikrim", answer: ""),
            ProfilePrompt(question: "Beraber deneyelim", answer: "")
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case name, birthDate, university, department, year, bio, interests, gender, datingPreference, relationshipIntent, prompts, discoveryFilters
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthDate = try container.decodeIfPresent(Date.self, forKey: .birthDate) ?? (Calendar.current.date(byAdding: .year, value: -21, to: .now) ?? .now)
        university = try container.decodeIfPresent(String.self, forKey: .university) ?? "YÜ"
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        year = try container.decodeIfPresent(String.self, forKey: .year) ?? "3. sınıf"
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        interests = try container.decodeIfPresent(Set<String>.self, forKey: .interests) ?? []
        gender = try container.decodeIfPresent(ProfileGender.self, forKey: .gender)
        datingPreference = try container.decodeIfPresent(DatingPreference.self, forKey: .datingPreference)
        relationshipIntent = try container.decodeIfPresent(RelationshipIntent.self, forKey: .relationshipIntent) ?? .both
        prompts = try container.decodeIfPresent([ProfilePrompt].self, forKey: .prompts) ?? Self.defaultPrompts
        discoveryFilters = try container.decodeIfPresent(DiscoveryFilters.self, forKey: .discoveryFilters) ?? DiscoveryFilters()
    }

    var age: Int {
        max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
