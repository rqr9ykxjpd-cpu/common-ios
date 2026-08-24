import SwiftUI
import UIKit

@MainActor
@Observable
final class AppState {
    enum SessionKey {
        static let isSignedIn = "session.isSignedIn"
        static let ghostMode = "session.ghostMode"
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
            case .system: L10n.Appearance.system
            case .light: L10n.Appearance.light
            case .dark: L10n.Appearance.dark
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
    var currentUserID: UUID
    var draft = ProfileDraft()
    var profiles: [StudentProfile] = []
    var discoveryFilters = DiscoveryFilters()
    var isLoadingDiscovery = false
    /// Keşif yükleme nesli: Yenile eski isteğin boş sonucunun desteyi ezmesini engeller.
    var discoveryLoadGeneration: UInt = 0
    /// Akış ve story'ler ilk kez yüklenirken. Boş liste ile "henüz yüklenmedi"
    /// ayırt edilemiyordu: akış yüklenirken ekranda "Akış henüz boş" yazıyordu,
    /// yani kullanıcıya yanlış bilgi veriliyordu.
    var isLoadingFeed = false
    var isLoadingStories = false
    var isLoadingConversations = false
    var isLoadingNotifications = false
    var isLoadingMessageRequests = false
    var isLoadingPlaces = false
    var isReactingToProfile = false
    var discoveryError: String?
    var conversationsError: String?
    var notificationsError: String?
    var messageRequestsError: String?
    var placesError: String?
    var conversations: [Conversation] = []
    /// Engellediğin kişiler; ayarlardaki liste için.
    var blockedProfiles: [BlockedProfile] = []
    var posts: [SocialPost] = []
    var stories: [CampusStory] = []
    var notifications: [AppNotification] = []
    /// Okundu diye işaretlenmiş ama sunucu henüz onaylamamış bildirimler.
    /// Liste yenilenince rozetin geri gelmesini engeller.
    var pendingNotificationReadIDs: Set<UUID> = []
    var meetingRequests: [MeetingRequest] = []

    /// Eşleşmeden gelen/giden yanıt istekleri.
    var messageRequests: [MessageRequest] = []

    /// Şikayet listesi. Yalnızca moderatör okuyabiliyor.
    var reports: [ModerationReport] = []
    var isLoadingReports = false

    /// Moderasyon ekranı yalnızca rozetli hesaplara açık. Rozeti sunucu
    /// veriyor (bkz. `set_badge`), istemci kendine veremiyor; buradaki kontrol
    /// yalnızca arayüzü gizlemek için — asıl kapı sunucudaki izin kuralları.
    var isModerator: Bool { myBadge == .founder || myBadge == .moderator }

    /// "Seni beğenenler" yalnızca kurucuya açık. Bilerek `isModerator` değil:
    /// moderatör rozeti ileride başkasına verilirse o kişi bu listeyi görmesin.
    /// Buradaki kontrol yalnızca arayüzü gizliyor; asıl kapı `who_liked_me`
    /// fonksiyonunun içindeki rozet kontrolü.
    var isFounder: Bool { myBadge == .founder }

    /// Hesabımı sağa kaydıranlar. Yalnızca kurucu doldurabiliyor.
    var admirers: [Admirer] = []
    var isLoadingAdmirers = false

    /// Cevap bekleyen şikayetler.
    var pendingReports: [ModerationReport] { reports.filter { $0.handledAt == nil } }

    /// Cevap bekleyen gelen istekler. Rozet ve liste bunu kullanıyor.
    var pendingMessageRequests: [MessageRequest] {
        messageRequests.filter { $0.direction == .incoming && $0.status == .pending }
    }
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
    var myBadge: ProfileBadge = .none

    /// Kullanıcının abonelik kademesi. `subscriptions` (StoreKit) buraya yazıyor;
    /// arayüz neyin kilitli olduğunu buradan okuyor.
    ///
    /// Bu değer **arayüz içindir**. Sayılı sınırları uygulayan sunucu kendi
    /// kaydına bakıyor; burayı kurcalayan biri Pro ekranlarını açabilir ama
    /// beğeni hakkını artıramaz.
    var tier: SubscriptionTier = .free

    /// StoreKit katmanı. Uygulama boyunca tek örnek: `Transaction.updates`
    /// dinleyicisi açılışta başlayıp hiç kapanmamalı.
    let subscriptions = SubscriptionStore()

    /// Hayalet mod (yalnızca Pro): açıkken profil ziyaretleri ve story
    /// izlemeleri kaydedilmiyor. İstemci göndermese de sunucu `ghost_mode`
    /// kolonuna bakıp isteği yutuyor — aksi halde uygulamayı kurcalayan
    /// biri iz bırakabilirdi.
    /// Sınıra takılınca açılan ekran ve hangi sınıra takıldığı.
    var paywallVisible = false
    var quotaHit: QuotaKind?

    var ghostMode: Bool {
        didSet { defaults.set(ghostMode, forKey: SessionKey.ghostMode) }
    }
    var isFinishingOnboarding = false
    /// Kayıt akışının son adımındaki hata. Toast kaybolduğu için kullanıcı düğmenin
    /// çalışmadığını sanıyordu; bu ekranda kalıcı olarak gösteriliyor.
    var onboardingFailure: String?
    var isAccountActionInProgress = false
    var toast: AppToastMessage?
    /// Kilit ekranındaki bildirime basınca bildirim listesini açmak için.
    var opensNotifications = false

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
        // Sunucu bir sınırı reddettiğinde ham hata göstermek yerine ne olduğunu
        // anlatan ekranı açıyoruz. Hata metnine değil koda bakıyoruz; metin
        // değişebilir, kod değişmez.
        if let sinir = quotaKind(error) {
            quotaHit = sinir
            paywallVisible = true
            return
        }
        if isClockSkew(error), recoverFromClockSkew() { return }
        toast = AppToastMessage(text: UserFacingError.message(error, fallback: fallback), kind: .error)
    }

    /// Sunucunun jetonu üreten servisiyle isteği doğrulayan servisin saatleri
    /// bir-iki saniye ayrıştığında PostgREST isteği "JWT issued at future" diye
    /// reddediyor. Cihazın saatiyle ilgisi yok, kullanıcının yapabileceği bir şey
    /// yok ve kendiliğinden geçiyor.
    func isClockSkew(_ error: Error) -> Bool {
        String(describing: error).contains("PGRST303")
    }

    /// Hata göstermek yerine kısa bir bekleyip ekranı bir kez kendimiz tazeliyoruz.
    /// Dakikada bir denenir: ikinci kez üst üste gelirse artık gizlemiyoruz, çünkü
    /// o zaman geçici bir sapma değil gerçekten bozuk bir şey var demektir.
    /// `true` dönerse hata yutuldu.
    func recoverFromClockSkew() -> Bool {
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
    func isNetworkFailure(_ error: Error) -> Bool {
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

    var lastClockSkewRecovery: Date?

    /// Sunucudaki sınır tetikleyicilerinin fırlattığı kodlar.
    func quotaKind(_ error: Error) -> QuotaKind? {
        let metin = String(describing: error)
        if metin.contains("QUOTA_LIKE") { return .like }
        if metin.contains("QUOTA_MEETING_REQUEST") { return .meetingRequest }
        if metin.contains("QUOTA_MEETING_ACCEPT") { return .meetingAccept }
        if metin.contains("QUOTA_POST") || metin.contains("POST_LIMIT") { return .posts }
        if case .postLimit = error as? BackendServiceError { return .posts }
        return nil
    }

    func isCancellation(_ error: Error) -> Bool {
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
    let defaults: UserDefaults
    var messageListenerTask: Task<Void, Never>?

#if DEBUG
    /// `-tab <ad>` ile açılan sekme. Yalnızca geliştirme derlemesinde.
    var initialTab = 0
    /// `-compose` ile paylaşım ekranı açılışta gösterilir.
    var opensComposer = false
    /// Yalnızca geliştirme derlemesinde: ilk kulübün sayfasını açar. Ekran
    /// görüntüsü almak için — o sayfaya normalde yalnızca dokunarak gidiliyor.
    var opensFirstClub = false
    var opensPlacesWall = false
    var opensChats = false
    var opensMessageRequests = false
    var opensModeration = false
    /// `-story`: eşleşilmemiş birinin story'sini açar — istek gönderme alanı
    /// yalnızca orada görünüyor. `-story <ad>` ile belirli biri seçilebilir.
    var opensStoryOf: String?
    var opensAnyStory = false
    /// `-profile [ad]`: kişi kartını açar; ad verilmezse kendi profilim.
    /// Kurucu profilinin nasıl göründüğünü görmenin başka yolu yok.
    var opensProfileOf: String??
    /// Yalnızca geliştirme derlemesinde: Plus ekranını açar (tasarım kontrolü).
    var opensPaywall = false
    var opensProNote = false
    /// Yalnızca geliştirme derlemesinde: kendi kart önizlemesini açar.
    var opensCardPreview = false
    /// `-onboarding <adım>` ile açıldığında oturum geri yüklemesi rotayı ezmesin diye.
    /// Yalnızca geliştirme derlemesinde var.
    var skipsSessionRestore = false
#endif

    var savedPosts: [SocialPost] = []

    init(service: (any ProductService)? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? ProductServiceFactory.make()
        self.defaults = defaults
        let hasSession = defaults.bool(forKey: SessionKey.isSignedIn)
        ghostMode = defaults.bool(forKey: SessionKey.ghostMode)
        route = hasSession ? .app : .welcome
        email = defaults.string(forKey: SessionKey.email) ?? defaults.string(forKey: SessionKey.accountEmail) ?? ""
        currentUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:)) ?? UUID()
        appearance = defaults.string(forKey: SessionKey.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        loadAccountData(migratingLegacy: true)

        // Cihaz bir hak gördüğünde arayüzü açıyoruz ve doğrulanmış işlemi
        // sunucuya bildiriyoruz. Sunucu Apple'a sormadan kademeyi değiştirmiyor;
        // bu çağrı bir talep, bir bildirim değil.
        subscriptions.onEntitlementChange = { [weak self] kademe, satinAlma in
            guard let self else { return }
            self.tier = kademe
            guard let satinAlma else { return }
            Task { await self.syncPlanWithServer(satinAlma) }
        }
    }

    /// Doğrulanmış satın almayı sunucuya iletir. Hata sessiz: kullanıcının
    /// satın alması başarılı oldu, arayüzü de açıldı. Sunucu bildirimi
    /// gecikirse `refreshEntitlements` bir sonraki açılışta tekrar deniyor —
    /// ekranına "abonelik kaydedilemedi" yazmak, parası gitmiş kullanıcıyı
    /// boşuna paniğe sokar.
    func syncPlanWithServer(_ satinAlma: SubscriptionStore.VerifiedPurchase) async {
        do {
            try await service.submitPurchase(jws: satinAlma.jws, productID: satinAlma.productID)
        } catch {
            #if DEBUG
            print("Abonelik sunucuya bildirilemedi: \(error)")
            #endif
        }
    }

    /// Açılışta: ürünleri yükle, cihazdaki hakları oku, sunucuya danış.
    ///
    /// Sunucu asıl kaynak — sınırları uygulayan o. Ama cihaz sunucudan daha
    /// yüksek bir hak görüyorsa (satın alma yeni oldu, doğrulama henüz
    /// düşmedi) kullanıcıyı bekletmiyoruz: arayüzü açıp doğrulamayı tekrar
    /// gönderiyoruz. Tersi durumda — sunucu daha yüksekse — sunucuya
    /// uyuyoruz; abonelik başka cihazda alınmış olabilir.
#if DEBUG
    /// `-tier plus|pro` ile elle verilen kademe. Açılıştaki abonelik tazelemesi
    /// bunu ezmesin diye tutuluyor: örnek modda sunucu da cihaz da 'free'
    /// döndürüyor ve bayrak hiç tutmuyordu, Pro ekranları test edilemiyordu.
    var debugTierOverride: SubscriptionTier?

    /// `-badge founder|moderator` ile elle verilen rozet. Kurucuya özel ekranlar
    /// örnek modda test edilemiyordu: örnek profilin rozeti `.none` geliyor ve
    /// giriş hiç görünmüyordu.
    var debugBadgeOverride: ProfileBadge?
#endif

    func refreshSubscriptions() async {
#if DEBUG
        if let debugTierOverride {
            tier = debugTierOverride
            return
        }
#endif
        await subscriptions.loadProducts()
        await subscriptions.refreshEntitlements()
        let cihaz = subscriptions.tier

        let sunucu: SubscriptionTier
        do {
            sunucu = try await service.fetchMyPlan()
        } catch {
            // Sunucu kademeyi bilmiyorsa (henüz oturum yok, ağ yok ya da
            // migration çalışmadıysa) cihazın bildiği geçerli. Kullanıcıya
            // hata göstermiyoruz: abonelik ekranıyla ilgisi olmayan bir anda
            // "abonelik okunamadı" demek kafa karıştırır.
            tier = cihaz
            return
        }

        tier = max(cihaz, sunucu)
        if cihaz > sunucu {
            await subscriptions.refreshEntitlements(forceSync: true)
        }
    }

    /// Profil/gönderi görseli. İmzalı URL GET başarısız olursa Storage indirmesi dener.
    func remoteImage(for url: URL) async -> UIImage? {
        let service = service
        return await BondImageLoader.shared.image(for: url) { target in
            await Self.fetchMediaData(target, service: service)
        }
    }

    func remoteImageData(for url: URL) async -> Data? {
        await Self.fetchMediaData(url, service: service)
    }

    nonisolated private static func fetchMediaData(_ url: URL, service: any ProductService) async -> Data? {
        if let supabase = service as? SupabaseProductService {
            return await supabase.loadMediaData(url)
        }
        if url.isFileURL { return try? Data(contentsOf: url) }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else { return nil }
        return data
    }
}
