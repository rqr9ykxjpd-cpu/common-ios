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
        static let appearance = "settings.appearance"

        static func account(_ key: String, userID: UUID) -> String {
            "account.\(userID.uuidString.lowercased()).\(key)"
        }
    }

    /// Kullanıcının seçtiği görünüm. Varsayılan "sistem"; koyu mod zorunlu değil,
    /// isteyen Profil > Görünüm'den açıyor.
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "Sistem"
            case .light: "Açık"
            case .dark: "Koyu"
            }
        }

        var icon: String {
            switch self {
            case .system: "iphone"
            case .light: "sun.max"
            case .dark: "moon"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum Route: Equatable {
        case welcome
        case onboarding(OnboardingStep)
        case app
    }

    enum OnboardingStep: Int, Equatable, CaseIterable {
        case identity, preferences, interests, photo, ready
    }

    var route: Route
    var email: String
    private(set) var currentUserID: UUID
    var draft = ProfileDraft()
    var profiles: [StudentProfile] = []
    var discoveryFilters = DiscoveryFilters()
    var isLoadingDiscovery = false
    var isReactingToProfile = false
    var discoveryError: String?
    var conversations: [Conversation] = []
    var posts: [SocialPost] = []
    var stories: [CampusStory] = []
    var notifications: [AppNotification] = []
    var meetingRequests: [MeetingRequest] = []
    /// Profilini görüntüleyenler; yalnızca sahibine görünür.
    var profileVisits: [ProfileVisit] = []
    /// Kampüs yerleri, `places` tablosundan gelir.
    var places: [CampusPlace] = []
    /// Kulüpler, `clubs` tablosundan gelir.
    var clubs: [CampusClub] = []
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
    /// Kendi rozetim. Sunucudan gelir; istemci kendine rozet veremez.
    private(set) var myBadge: ProfileBadge = .none
    var isFinishingOnboarding = false
    /// Kayıt akışının son adımındaki hata. Toast kaybolduğu için kullanıcı düğmenin
    /// çalışmadığını sanıyordu; bu ekranda kalıcı olarak gösteriliyor.
    private(set) var onboardingFailure: String?
    var isAccountActionInProgress = false
    var toast: AppToastMessage?

    /// Kısa bilgi mesajı gösterir (yeşil tik).
    func show(_ message: String) {
        toast = AppToastMessage(text: message, kind: .info)
    }

    /// Hata gösterir (kırmızı ünlem). Ham sunucu metni kullanıcıya çıkmaz; bkz. `UserFacingError`.
    ///
    /// İptal edilen görevler hata sayılmaz. `loadStories` gibi yüklemeler ekran
    /// kapandığında ya da yeni bir yükleme başladığında iptal ediliyor; bu
    /// `CancellationError` olarak geliyordu ve kullanıcı sebepsiz yere
    /// "Story'ler yüklenemedi" görüyordu. Ortada bir arıza yok, sadece istek
    /// artık gereksiz.
    func showError(_ error: Error, fallback: String) {
        guard !isCancellation(error) else { return }
        if isClockSkew(error), recoverFromClockSkew() { return }
        toast = AppToastMessage(text: UserFacingError.message(error, fallback: fallback), kind: .error)
    }

    /// Sunucunun jetonu üreten servisiyle isteği doğrulayan servisin saatleri
    /// bir-iki saniye ayrıştığında PostgREST isteği "JWT issued at future" diye
    /// reddediyor. Cihazın saatiyle ilgisi yok, kullanıcının yapabileceği bir şey
    /// yok ve kendiliğinden geçiyor.
    private func isClockSkew(_ error: Error) -> Bool {
        String(describing: error).contains("PGRST303")
    }

    /// Hata göstermek yerine kısa bir bekleyip ekranı bir kez kendimiz tazeliyoruz.
    /// Dakikada bir denenir: ikinci kez üst üste gelirse artık gizlemiyoruz, çünkü
    /// o zaman geçici bir sapma değil gerçekten bozuk bir şey var demektir.
    /// `true` dönerse hata yutuldu.
    private func recoverFromClockSkew() -> Bool {
        let now = Date()
        if let last = lastClockSkewRecovery, now.timeIntervalSince(last) < 60 { return false }
        lastClockSkewRecovery = now
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard route == .app else { return }
            await loadPlaces(silently: true)
            await loadFeed()
            await loadStories()
            await loadConversations()
            await loadNotifications()
        }
        return true
    }

    /// Sunucuya ulaşılamaması ile oturumun geçersiz olması ayrı şeyler; ilkinde
    /// kullanıcıyı çıkışa zorlamıyoruz.
    private func isNetworkFailure(_ error: Error) -> Bool {
        let kodlar: Set<Int> = [
            NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
            NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed,
            NSURLErrorSecureConnectionFailed
        ]
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && kodlar.contains(nsError.code)
    }

    private var lastClockSkewRecovery: Date?

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return (error as NSError).code == NSURLErrorCancelled
    }

    /// Kendi ürettiğimiz, hataya karşılık gelen mesajlar için.
    func showError(_ message: String) {
        toast = AppToastMessage(text: message, kind: .error)
    }

    /// Seçilen görünüm. Değişince anında kaydedilir; uygulama yeniden açıldığında korunur.
    var appearance: Appearance = .system {
        didSet { defaults.set(appearance.rawValue, forKey: SessionKey.appearance) }
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
        appearance = defaults.string(forKey: SessionKey.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        loadAccountData(migratingLegacy: true)
    }

    /// Apple'ın verdiği ham (hash'lenmemiş) nonce'u geçir; `SupabaseProductService` bunu
    /// olduğu gibi Supabase'e iletir, hash'lenmiş hali yalnızca Apple'a giden istekte kullanılır.
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        do {
            try await service.signInWithApple(idToken: idToken, nonce: nonce)
        } catch {
            showError(error, fallback: "Apple ile giriş yapılamadı.")
            return false
        }
        return await completeSocialSignIn()
    }

    @discardableResult
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async -> Bool {
        do {
            try await service.signInWithGoogle(idToken: idToken, accessToken: accessToken, nonce: nonce)
        } catch {
            showError(error, fallback: "Google ile giriş yapılamadı.")
            return false
        }
        return await completeSocialSignIn()
    }

    /// Apple/Google ikisi de aynı sonrası akışı paylaşır: yeni hesapsa onboarding'e,
    /// profili tamamlanmışsa doğrudan uygulamaya geçer.
    /// Girişin kendisi başarılı olduktan sonrası. Buradaki bir hata "giriş yapılamadı"
    /// değildir — oturum açıldı, profil yüklenemedi. Önceden ikisi tek `catch`'te
    /// birleşiyordu ve profil çözümlenemediğinde kullanıcıya "Google ile giriş
    /// yapılamadı" deniyordu; sebebi bambaşka bir yerdeyken yanlış yere baktırıyordu.
    private func completeSocialSignIn() async -> Bool {
        currentUserID = service.currentUserID ?? currentUserID
        if let sessionEmail = service.currentUserEmail {
            email = sessionEmail.lowercased()
        }
        restoreOrCreateAccount(for: email)

        let profile: ProfileDraft?
        do {
            profile = try await service.fetchMyProfile()
        } catch {
            showError(error, fallback: "Giriş yapıldı ama profilin yüklenemedi. Tekrar dene.")
            return false
        }
        guard let profile else {
            persistSession()
            withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.identity) }
            return true
        }
        applyRemoteProfile(profile)
        persistSession()
        await loadMyProfilePhotos()
        await loadNotifications()
        await loadPlaces(silently: true)
        await loadStories()
        await loadClubs(silently: true)
        await loadMeetingRequests()
        await loadProfileVisits(silently: true)
        try? await service.touchLastActive()
        startMessageListener()
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        show(name.isEmpty ? "Hoş geldin!" : "Hoş geldin, \(name)!")
        return true
    }

#if DEBUG
    /// `-tab <ad>` ile açılan sekme. Yalnızca geliştirme derlemesinde.
    var initialTab = 0
    /// `-compose` ile paylaşım ekranı açılışta gösterilir.
    var opensComposer = false
    /// `-onboarding <adım>` ile açıldığında oturum geri yüklemesi rotayı ezmesin diye.
    /// Yalnızca geliştirme derlemesinde var.
    var skipsSessionRestore = false
#endif

    func restoreBackendSession() async {
#if DEBUG
        if skipsSessionRestore { return }
#endif
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
                showError("Profilini tamamlaman gerekiyor.")
                withAnimation(.smooth(duration: 0.45)) { route = .onboarding(.identity) }
                return
            }
            applyRemoteProfile(profile)
            if !email.isEmpty { persistSession() }
            await loadMyProfilePhotos()
            await loadNotifications()
            await loadPlaces(silently: true)
            await loadStories()
            await loadClubs(silently: true)
            await loadMeetingRequests()
            await loadProfileVisits(silently: true)
            try? await service.touchLastActive()
            startMessageListener()
            // Geçerli oturum ve tamamlanmış profil varken karşılama ekranında bırakmak
            // kullanıcıyı hiçbir yere gidemez halde bırakıyordu.
            if route != .app {
                withAnimation(.smooth(duration: 0.45)) { route = .app }
            }
        } catch {
            // Ağın kopması oturumun bittiği anlamına gelmiyor. Kampüs wifi'ında bir istek
            // zaman aşımına uğradığında kullanıcıyı karşılama ekranına atmak, girişi
            // düşmüş gibi gösteriyordu; oysa oturum Keychain'de duruyor ve profil de
            // yerelde önbellekli. Kullanıcıyı olduğu yerde bırakıp durumu söylüyoruz.
            if isNetworkFailure(error) {
                showError(error, fallback: "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.")
            } else {
                route = .welcome
                showError(error, fallback: "Oturum geri yüklenemedi.")
            }
        }
    }

    /// Sunucudaki profili yerel duruma yazar. `draft` yalnızca UserDefaults'tan geldiği için
    /// kullanıcı başka bir cihazdan girdiğinde profili sunucuda dururken boş görünüyordu.
    private func applyRemoteProfile(_ profile: ProfileDraft) {
        draft = profile
        myBadge = profile.badge
        discoveryFilters = profile.discoveryFilters
        persistAccount()
    }

    private func loadMyProfilePhotos() async {
        do {
            let result = try await service.fetchMyProfilePhotos()
            avatarURL = result.avatarURL
            galleryURLs = result.galleryURLs
        } catch {
            showError(error, fallback: "Profil fotoğrafların yüklenemedi.")
        }
    }

    /// Sohbet ekranı açık olmasa da eşleşmelerdeki yeni mesajları anlık yakalar —
    /// aksi halde `ConversationView` yalnızca açılış anında bir kerelik yüklüyor,
    /// karşı taraf yazınca ekranda görünmüyor.
    private func startMessageListener() {
        guard messageListenerTask == nil else { return }
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

    /// Uygulama arka plandan öne döndüğünde çağrılır.
    ///
    /// Anlık kanal arka planda kopuyor ve bu sırada gelen mesajlar kaçıyor. Yeniden
    /// bağlanma kendiliğinden oluyor ama kaçırılan mesajları getirmiyor; burada
    /// sunucudan tazeliyoruz. Bildirimler ve story'ler de aynı sebeple yenileniyor.
    func refreshAfterForeground() async {
        guard route == .app else { return }
        await loadConversations()
        await loadNotifications()
        await loadStories()
        try? await service.touchLastActive()
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
        onboardingFailure = nil
        do {
            try await service.saveProfile(draft)
        } catch {
            let message = UserFacingError.message(error, fallback: "Profilin kaydedilemedi.")
            onboardingFailure = message
            showError(message)
            return
        }

        // Fotoğraf yüklemesi ayrı ele alınıyor. Aynı `do` bloğundayken profil sunucuya
        // kaydedilmiş olmasına rağmen "Profilin kaydedilemedi" deniyor ve kullanıcı kayıt
        // ekranında kalıyordu — yani tek bir fotoğraf yüzünden uygulamaya hiç giremiyordu.
        // Profil hazırsa içeri alıyoruz; fotoğrafı Profil > Düzenle'den sonradan ekler.
        var photoFailed = false
        if let avatarData {
            do {
                avatarURL = try await service.updateAvatar(avatarData)
            } catch {
                photoFailed = true
            }
        }

        persistSession()
        // Kayıt akışıyla giren kullanıcı da anlık mesajları almalı; bunlar yalnızca `signIn` ve
        // `restoreBackendSession` içinde kuruluyordu, yeni kullanıcı uygulamayı yeniden
        // başlatana kadar gelen mesajları görmüyordu.
        await loadMyProfilePhotos()
        await loadNotifications()
        await loadPlaces(silently: true)
        await loadStories()
        await loadClubs(silently: true)
        await loadMeetingRequests()
        try? await service.touchLastActive()
        startMessageListener()

        onboardingFailure = nil
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        if photoFailed {
            showError("Profilin kaydedildi, fotoğrafın yüklenemedi. Profil'den tekrar deneyebilirsin.")
        } else {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            show(name.isEmpty ? "Hoş geldin!" : "Hoş geldin, \(name)!")
        }
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
            discoveryError = UserFacingError.message(error, fallback: "Yeni profiller yüklenemedi.")
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
            if result.matched, let matchID = result.matchID {
                currentMatch = profile
                _ = conversationID(for: profile, matchID: matchID)
                // Backend modunda eşleşme bildirimini veritabanı trigger'ı üretiyor; burada
                // ayrıca eklersek aynı bildirim iki kez görünür.
            }
            if profiles.count < 3 { await loadDiscovery() }
        } catch {
            discoveryError = UserFacingError.message(error, fallback: "İşlemin kaydedilemedi.")
        }
    }

    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let newLiked = !posts[index].liked
        posts[index].liked = newLiked
        posts[index].likeCount += newLiked ? 1 : -1
        Haptics.impact(.light)
        Task {
            do {
                try await service.setPostLiked(postID, liked: newLiked)
            } catch {
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].liked = !newLiked
                posts[refreshedIndex].likeCount += newLiked ? -1 : 1
                showError(error, fallback: "Beğeni kaydedilemedi.")
            }
        }
    }

    func loadFeed() async {
        // Gönderinin yeri, sunucudan gelen yer *adı* `places` listesiyle eşleştirilerek
        // çözülüyor ve dönüşüm anında sabitleniyor. Akış ekranı açılışta `loadFeed`'i
        // kendi başına çağırdığı için bu, yerleri yükleyen `restoreBackendSession` ile
        // yarışıyordu: akış önce biterse bütün gönderiler konum etiketini kaybediyor ve
        // kullanıcı akışı elle yenileyene kadar geri gelmiyordu.
        if places.isEmpty { await loadPlaces() }
        do {
            posts = try await service.fetchFeed().map(socialPost(from:))
        } catch {
            showError(error, fallback: "Akış yüklenemedi.")
        }
    }

    func publishPost(imageData: Data?, caption: String, place: CampusPlace?) {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageData != nil || !cleanCaption.isEmpty else { return }
        Task {
            do {
                let post = try await service.createPost(caption: cleanCaption, placeName: place?.name, imageData: imageData)
                posts.insert(socialPost(from: post), at: 0)
                Haptics.success()
            } catch {
                showError(error, fallback: "Gönderi paylaşılamadı.")
            }
        }
    }

    /// Story'leri sunucudan yükler. Bu liste akışın en üstünde duruyor ama şimdiye kadar
    /// yalnızca bellekteydi; uygulama kapanınca paylaşılan story kayboluyordu.
    func loadStories() async {
        // Kendi süresi dolmuş story'lerini de temizliyoruz: aksi halde her paylaşım
        // depolamada kalıcı olarak yer kaplıyor. En-iyi-çaba, sonucu beklenmiyor.
        Task { await service.purgeMyExpiredStories() }
        do {
            stories = try await service.fetchStories()
        } catch {
            showError(error, fallback: "Story'ler yüklenemedi.")
        }
    }

    func publishStory(imageData: Data, caption: String, place: CampusPlace?) {
        Task {
            do {
                try await service.publishStory(imageData: imageData, caption: caption, placeID: place?.id)
                await loadStories()
                Haptics.success()
            } catch {
                showError(error, fallback: "Story paylaşılamadı.")
            }
        }
    }

    /// Gönderi hem akışta hem kaydedilenler listesinde bulunabilir; ikisi de güncelleniyor.
    ///
    /// Önceden yalnızca akışa bakılıyordu (`guard let index = posts.firstIndex...`).
    /// Kaydedilenler sayfasında akışta olmayan eski bir gönderinin yer imini kaldırmaya
    /// çalışınca guard'a takılıyor ve düğme hiçbir şey yapmıyordu.
    func toggleSaved(postID: UUID) {
        let current = posts.first(where: { $0.id == postID })?.saved
            ?? savedPosts.contains(where: { $0.id == postID })
        let newSaved = !current

        applySaved(newSaved, to: postID)
        Haptics.impact(.light)
        Task {
            do {
                try await service.setPostSaved(postID, saved: newSaved)
            } catch {
                applySaved(!newSaved, to: postID)
                showError(error, fallback: "Kaydetme işlemi tamamlanamadı.")
            }
        }
    }

    private func applySaved(_ saved: Bool, to postID: UUID) {
        if let index = posts.firstIndex(where: { $0.id == postID }) {
            posts[index].saved = saved
        }
        if saved {
            if !savedPosts.contains(where: { $0.id == postID }),
               var post = posts.first(where: { $0.id == postID }) {
                post.saved = true
                savedPosts.insert(post, at: 0)
            }
        } else {
            savedPosts.removeAll { $0.id == postID }
        }
    }

    /// Kaydedilen gönderiler. Yer imi butonu yalnızca yerel durumu değiştiriyordu ve
    /// kaydedilenleri görecek bir ekran da yoktu; buton hiçbir işe yaramıyordu.
    /// Kaydedilen gönderiler sunucudan ayrıca çekiliyor; akıştan süzmek yetmiyordu
    /// çünkü akış yalnızca son 100 gönderiyi getiriyor.
    private(set) var savedPosts: [SocialPost] = []

    func loadSavedPosts() async {
        do {
            savedPosts = try await service.fetchSavedPosts().map(socialPost(from:))
        } catch {
            showError(error, fallback: "Kaydedilenler yüklenemedi.")
        }
    }

    func deletePost(_ postID: UUID) {
        guard posts.contains(where: { $0.id == postID && $0.isMine }) else { return }
        Task {
            do {
                try await service.deletePost(postID)
                posts.removeAll { $0.id == postID }
                show("Gönderi silindi")
                Haptics.success()
            } catch {
                showError(error, fallback: "Gönderi silinemedi.")
            }
        }
    }

    func deleteStory(_ storyID: UUID) {
        guard let removed = stories.first(where: { $0.id == storyID && $0.isMine }) else { return }
        stories.removeAll { $0.id == storyID }
        if selectedStory?.id == storyID { selectedStory = nil }
        show("Story silindi")
        Haptics.success()
        Task {
            do { try await service.deleteStory(storyID) }
            catch {
                stories.insert(removed, at: 0)
                showError(error, fallback: "Story silinemedi.")
            }
        }
    }

    func addComment(_ body: String, to postID: UUID) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty, posts.contains(where: { $0.id == postID }) else { return }
        Task {
            do {
                let comment = try await service.addComment(cleanBody, to: postID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.append(socialComment(from: comment))
                Haptics.impact(.light)
            } catch {
                showError(error, fallback: "Yorum gönderilemedi.")
            }
        }
    }

    func deleteComment(_ commentID: UUID, from postID: UUID) {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              posts[postIndex].comments.contains(where: { $0.id == commentID && $0.isMine }) else { return }
        Task {
            do {
                try await service.deleteComment(commentID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.removeAll { $0.id == commentID }
                show("Yorum silindi")
                Haptics.success()
            } catch {
                showError(error, fallback: "Yorum silinemedi.")
            }
        }
    }

    func block(_ profile: StudentProfile) {
        Task {
            do {
                try await service.blockUser(profile.id)
                profiles.removeAll { $0.id == profile.id }
                conversations.removeAll { $0.profile.id == profile.id }
                posts.removeAll { $0.author.id == profile.id }
                notifications.removeAll { $0.actor?.id == profile.id }
                if selectedConversation?.profile.id == profile.id { selectedConversation = nil }
                show("\(profile.name) engellendi")
                Haptics.success()
            } catch {
                showError(error, fallback: "Engelleme işlemi tamamlanamadı.")
            }
        }
    }

    /// Eşleşmeyi sonlandırır. Engellemeden farklı olarak karşı taraf engellenmiş olmaz;
    /// tek çıkış yolu engellemek olduğu için insanlar sıkıldıkları kişiyi engellemek
    /// zorunda kalıyordu.
    func unmatch(_ conversationID: UUID) {
        let previous = conversations
        conversations.removeAll { $0.id == conversationID }
        if selectedConversation?.id == conversationID { selectedConversation = nil }
        Task {
            do {
                try await service.unmatch(conversationID)
                show("Eşleşme sonlandırıldı")
                Haptics.success()
            } catch {
                conversations = previous
                showError(error, fallback: "Eşleşme sonlandırılamadı.")
            }
        }
    }

    func report(_ profile: StudentProfile, reason: ReportReason) {
        Task {
            do {
                try await service.reportUser(profile.id, reason: reason, details: nil)
                show("Şikâyetin alındı, incelenecek")
                Haptics.success()
            } catch {
                showError(error, fallback: "Şikayet gönderilemedi.")
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
            // Rozet hiç aktarılmıyordu: kullanıcı kendi kartına baktığında
            // kurucu/moderatör rozetini göremiyordu.
            badge: myBadge,
            compatibilityReasons: [],
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
        } catch {
            showError(error, fallback: "Profil değişiklikleri kaydedilemedi.")
            return false
        }

        draft = updatedDraft
        avatarData = avatar
        profileGalleryData = gallery
        discoveryFilters = updatedDraft.discoveryFilters

        // Fotoğraf yüklemesi metin kaydından ayrı. Aynı `do` bloğundayken bir fotoğraf
        // hatası üç şeyi birden bozuyordu: metinler sunucuya yazılmış olmasına rağmen
        // "kaydedilemedi" deniyor, `persistAccount()` hiç çalışmadığı için yerel kayıt
        // sunucudan farklı kalıyor ve ekran kapanmadığı için kullanıcı baştan deniyordu.
        var photoFailed = false
        do {
            avatarURL = try await service.updateAvatar(avatar)
            galleryURLs = try await service.updateGallery(gallery)
        } catch {
            photoFailed = true
        }

        persistAccount()
        if photoFailed {
            showError("Bilgilerin kaydedildi, fotoğrafların yüklenemedi. Tekrar deneyebilirsin.")
        } else {
            show("Profilin güncellendi")
            Haptics.success()
        }
        return true
    }

    func markStoryViewed(_ story: CampusStory) {
        guard let storyIndex = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[storyIndex].viewed = true

        let storyID = story.id
        let isMine = story.isMine
        Task {
            try? await service.markStoryViewed(storyID)
            // İzleyen listesini yalnızca story sahibi görebilir; başkasının story'sinde
            // bu sorgu boş döneceği için hiç yapmıyoruz.
            guard isMine else { return }
            do {
                let records = try await service.fetchStoryViews(storyID)
                guard let index = stories.firstIndex(where: { $0.id == storyID }) else { return }
                stories[index].viewRecords = records
            } catch {
                showError(error, fallback: "Story'yi kimlerin gördüğü yüklenemedi.")
            }
        }
    }

    func meetingRequest(for profile: StudentProfile, at place: CampusPlace) -> MeetingRequest? {
        meetingRequests.first {
            $0.profile.id == profile.id && $0.place.id == place.id && $0.direction == .outgoing && $0.status == .pending
        }
    }

    /// Buluşma isteklerini sunucudan yükler. Bu liste şimdiye kadar yalnızca bellekte
    /// yaşıyordu; uygulama kapanınca gönderilen ve gelen istekler kayboluyordu.
    /// Profilini görüntüleyenler. Kayıt yalnızca sunucudaki RPC ile oluşuyor ve
    /// listeyi yalnızca profil sahibi görebiliyor.
    /// - Parameter silently: Girişte diğer yüklemelerle birlikte çağrıldığında `true`.
    ///   Ağ yoksa arka arkaya beş ayrı hata mesajı göstermek yerine sessiz kalıyoruz;
    ///   kullanıcı listeyi kendisi yenilediğinde ise sebebi görmesi gerekiyor.
    func loadProfileVisits(silently: Bool = false) async {
        do {
            profileVisits = try await service.fetchProfileVisits()
        } catch {
            if !silently { showError(error, fallback: "Ziyaretçilerin yüklenemedi.") }
        }
    }

    /// Birinin profili kasıtlı olarak açıldığında çağrılır. Keşif destesinde
    /// kart çevirmek ziyaret sayılmaz — orada niyet "bakınmak", "profiline gitmek" değil.
    func recordProfileVisit(_ profile: StudentProfile) {
        guard profile.id != currentUserID else { return }
        Task { try? await service.recordProfileVisit(profile.id) }
    }

    func loadMeetingRequests() async {
        do {
            meetingRequests = try await service.fetchMeetingRequests()
        } catch {
            showError(error, fallback: "Buluşma istekleri yüklenemedi.")
        }
    }

    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadPlaces(silently: Bool = false) async {
        do {
            let loaded = try await service.fetchPlaces()
            if !loaded.isEmpty { places = loaded }
        } catch {
            if !silently { showError(error, fallback: "Kampüs yerleri yüklenemedi.") }
        }
    }

    func sendMeetingRequest(to profile: StudentProfile, at place: CampusPlace) {
        guard meetingRequest(for: profile, at: place) == nil else { return }
        let optimistic = MeetingRequest(profile: profile, place: place, direction: .outgoing)
        meetingRequests.insert(optimistic, at: 0)
        Task {
            do {
                try await service.sendMeetingRequest(to: profile.id, placeID: place.id)
                await loadMeetingRequests()
                show("\(profile.name) için \(place.name) buluşma isteği gönderildi")
                Haptics.success()
            } catch {
                meetingRequests.removeAll { $0.id == optimistic.id }
                showError(error, fallback: "Buluşma isteği gönderilemedi.")
            }
        }
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) {
        guard let index = meetingRequests.firstIndex(where: { $0.id == requestID && $0.direction == .incoming && $0.status == .pending }) else { return }
        let previous = meetingRequests[index].status
        meetingRequests[index].status = accept ? .accepted : .declined
        notifications.removeAll { $0.meetingRequestID == requestID }
        show(accept ? "Buluşma isteği kabul edildi" : "Buluşma isteği reddedildi")
        Haptics.success()
        Task {
            do {
                try await service.respondToMeetingRequest(requestID, accept: accept)
            } catch {
                if let refreshed = meetingRequests.firstIndex(where: { $0.id == requestID }) {
                    meetingRequests[refreshed].status = previous
                }
                showError(error, fallback: "Buluşma isteği yanıtlanamadı.")
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
        show(turningOff ? "Yer görünürlüğün kapatıldı" : "Şu an \(place.name) konumunda görünürsün")
        Haptics.success()
        Task {
            do {
                try await service.setVisiblePlace(turningOff ? nil : place.id)
            } catch {
                currentVisiblePlace = previous
                showError(error, fallback: "Konum görünürlüğü değiştirilemedi.")
            }
        }
    }

    /// Bir yerde şu an görünen kişiler. Bu liste koda gömülü sabit isimlerdi; herkese
    /// aynı sahte kişiler gösteriliyordu.
    func peopleAtPlace(_ place: CampusPlace) async -> [StudentProfile] {
        do {
            return try await service.fetchPeopleAtPlace(place.id)
        } catch {
            showError(error, fallback: "Buradaki kişiler yüklenemedi.")
            return []
        }
    }

    func isJoined(to club: CampusClub) -> Bool {
        joinedClubIDs.contains(club.id)
    }

    /// Kulüpleri ve üyeliklerini sunucudan yükler. Liste eskiden koda gömülüydü ve
    /// katılma bilgisi yalnızca bellekte tutulduğu için uygulama kapanınca kayboluyordu.
    /// - Parameter silently: bkz. `loadProfileVisits(silently:)`.
    func loadClubs(silently: Bool = false) async {
        do {
            let result = try await service.fetchClubs()
            clubs = result.clubs
            joinedClubIDs = result.joinedIDs
        } catch {
            if !silently { showError(error, fallback: "Kulüpler yüklenemedi.") }
        }
    }

    func toggleClubMembership(_ club: CampusClub) {
        let willJoin = !joinedClubIDs.contains(club.id)
        if willJoin {
            joinedClubIDs.insert(club.id)
            show("\(club.name) kulübüne katıldın")
        } else {
            joinedClubIDs.remove(club.id)
            show("\(club.name) üyeliğinden ayrıldın")
        }
        Haptics.success()
        Task {
            do {
                try await service.setClubMembership(club.id, joined: willJoin)
                await loadClubs()
            } catch {
                if willJoin { joinedClubIDs.remove(club.id) } else { joinedClubIDs.insert(club.id) }
                showError(error, fallback: "Kulüp üyeliği güncellenemedi.")
            }
        }
    }

    func loadConversations() async {
        do {
            conversations = try await service.fetchConversations()
        } catch {
            showError(error, fallback: "Sohbetler yüklenemedi.")
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
        do {
            notifications = try await service.fetchNotifications().map(appNotification(from:))
        } catch {
            showError(error, fallback: "Bildirimler yüklenemedi.")
        }
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }), !notifications[index].isRead else { return }
        notifications[index].isRead = true
        Task {
            do { try await service.markNotificationRead(notificationID) }
            catch {
                if let refreshed = notifications.firstIndex(where: { $0.id == notificationID }) {
                    notifications[refreshed].isRead = false
                }
                showError(error, fallback: "Bildirim güncellenemedi.")
            }
        }
    }

    func markAllNotificationsRead() {
        let previous = notifications
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        Task {
            do { try await service.markAllNotificationsRead() }
            catch {
                notifications = previous
                showError(error, fallback: "Bildirimler güncellenemedi.")
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
            // Kullanıcının başlatmadığı arka plan işi: başarısız olursa okunmadı rozeti
            // kalır, başka bir sonucu yok. Hata göstermek gürültü olurdu; Tanış ekranına
            // yazmak ise büsbütün yanlıştı — orası keşif hataları için.
            catch { }
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
            showError(error, fallback: "Mesaj gönderilemedi.")
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
                showError(error, fallback: "Tepki kaydedilemedi.")
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
            showError(error, fallback: "Çıkış yapılamadı.")
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
            showError(error, fallback: "Hesap silinemedi.")
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
        notifications = []
        meetingRequests = []
        profileVisits = []
        currentMatch = nil
        selectedConversation = nil
        selectedStory = nil
        selectedPlaceFilter = nil
        currentVisiblePlace = nil
        joinedClubIDs = []
        myBadge = .none

        // Geçici bayraklar da sıfırlanmalı. Çıkış bir yükleme sürerken yapılırsa
        // `isLoadingDiscovery` true kalıyor ve sonraki girişte `loadDiscovery`
        // başındaki guard yüzünden keşif hiç yüklenmiyordu.
        isLoadingDiscovery = false
        isReactingToProfile = false
        isFinishingOnboarding = false
        onboardingFailure = nil
        discoveryError = nil
        toast = nil

        // `places`, `clubs` herkese açık referans verisi; `appearance` kullanıcının
        // cihaz tercihi. Bunlar kasıtlı olarak korunuyor.
        route = .welcome
        Haptics.success()
    }

    private func restoreOrCreateAccount(for signedInEmail: String) {
        if let backendUserID = service.currentUserID {
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
            isVerified: post.authorVerified,
            badge: post.authorBadge
        )
        return SocialPost(
            id: post.id,
            author: author,
            caption: post.caption,
            localImageData: post.imageData,
            place: post.placeName.flatMap { name in places.first { $0.name == name } },
            liked: post.liked,
            saved: post.saved,
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

    /// Kimlerin gösterileceği artık ayrı bir soru değil, cinsiyetten türetiliyor.
    /// Kadın seçen erkekleri, erkek seçen kadınları görüyor.
    var impliedDatingPreference: DatingPreference {
        switch self {
        case .female: .men
        case .male: .women
        }
    }

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
    /// Ayrı bir soru olarak sorulmuyor; cinsiyetten türetiliyor. Hesaplanan olması,
    /// ikisinin birbirinden ayrı düşüp tutarsız kalmasını da imkânsız kılıyor.
    var datingPreference: DatingPreference? { gender?.impliedDatingPreference }
    var relationshipIntent: RelationshipIntent = .both
    /// Sunucudan gelir. `save_my_profile` bunu parametre olarak almıyor, yani
    /// istemci kendine rozet veremiyor — buradaki değer yalnızca gösterim için.
    var badge: ProfileBadge = .none
    var discoveryFilters = DiscoveryFilters()

    private enum CodingKeys: String, CodingKey {
        case name, birthDate, university, department, year, bio, interests, gender, relationshipIntent, badge, discoveryFilters
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
        relationshipIntent = try container.decodeIfPresent(RelationshipIntent.self, forKey: .relationshipIntent) ?? .both
        badge = try container.decodeIfPresent(ProfileBadge.self, forKey: .badge) ?? .none
        discoveryFilters = try container.decodeIfPresent(DiscoveryFilters.self, forKey: .discoveryFilters) ?? DiscoveryFilters()
    }

    var age: Int {
        max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
