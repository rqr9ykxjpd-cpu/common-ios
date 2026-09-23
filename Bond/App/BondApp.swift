import SwiftUI
import GoogleSignIn
import RevenueCat

@main
struct BondApp: App {
    @UIApplicationDelegateAdaptor(BondAppDelegate.self) private var appDelegate
    @State private var appState = BondApp.initialState()

    /// Normalde gerçek servisle başlar.
    ///
    /// Yalnızca DEBUG'da: `-sample` argümanı verilirse (Xcode şemasına eklenerek ya da
    /// `simctl launch ... -sample` ile) uygulama örnek veriyle açılır. Bu, sunucu
    /// olmadan ekranları gezmek ve geliştirirken doğrulama yapmak için. Arayüzde
    /// bunu tetikleyen bir düğme yok — kullanıcıya hiçbir yerde görünmez.
    private static func configureRevenueCat() {
#if DEBUG
        // Offline design fixtures must not create RevenueCat customers.
        let arguments = ProcessInfo.processInfo.arguments
        guard !isSampleMode, !arguments.contains("-welcome") else { return }
#endif
        let key = AppSecrets.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, Purchases.isConfigured == false else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
    }

#if DEBUG
    /// Örnek veri modu. `-sample` ile bir kez açılınca hatırlanır: telefonda
    /// Xcode'dan bir kez başlatıp sonra ana ekrandan açınca da örnek veriyle
    /// gelsin, sunucuya tek satır gitmeden. `-live` unutturur ve gerçek servise
    /// döner. Yalnızca DEBUG; App Store derlemesinde bu kod hiç yok.
    private static var isSampleMode: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard
        let key = "debug.sampleMode"
        if arguments.contains("-live") {
            defaults.removeObject(forKey: key)
            return false
        }
        if arguments.contains("-sample") {
            defaults.set(true, forKey: key)
            return true
        }
        return defaults.bool(forKey: key)
    }
#endif

    private static func initialState() -> AppState {
        configureRevenueCat()
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        // Karşılama ekranını gerçek Supabase/Apple oturumunu ve sistem izinlerini
        // tetiklemeden görsel olarak doğrulamak için yalnızca Debug rotası.
        if arguments.contains("-welcome") {
            let state = AppState(service: SampleProductService())
            state.route = .welcome
            state.skipsSessionRestore = true
            return state
        }
        if isSampleMode {
            // `-onboarding` kayıt akışını baştan açar: örnek servis "sunucuda profil
            // yok" der, uygulama da gerçek yeni kullanıcıdaki gibi kayıt akışına
            // yönlendirir. Sunucu olmadan bu ekranları görmenin başka yolu yok.
            // İsteğe bağlı olarak adım adı verilebilir: `-onboarding ready`
            let onboarding = arguments.contains("-onboarding")
            // `-edu none|pending|verified|exempt`: öğrenci e-postası kartının durumları.
            var edu = EduVerificationStatus.unknown
            if let i = arguments.firstIndex(of: "-edu"), i + 1 < arguments.count {
                switch arguments[i + 1] {
                case "pending": edu.pendingEmail = "220207018@ogrenci.yalova.edu.tr"
                case "verified": edu.email = "220207018@ogrenci.yalova.edu.tr"; edu.verifiedAt = .now
                case "exempt": edu.exempt = true
                default: break
                }
            }
            let state = AppState(service: SampleProductService(hasProfile: !onboarding, eduStatus: edu))
            if !onboarding, let asset = SampleData.me.imageAssetName {
                state.avatarData = UIImage(named: asset)?.jpegData(compressionQuality: 0.85)
            }
            // `-tab profile|people|feed` doğrudan o sekmeyi açar. Ekranı görmeden
            // tasarım değiştirmek körlemesine çalışmak olurdu.
            if let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count {
                // İnsanlar / discovery sekmesi kaldırıldı (App Store 4.3(b)).
                state.initialTab = ["feed": 0, "places": 1, "chats": 2, "profile": 3][arguments[index + 1]] ?? 0
            }
            if arguments.contains("-compose") { state.opensComposer = true }
            if arguments.contains("-club") { state.opensFirstClub = true }
            if arguments.contains("-places") { state.opensPlacesWall = true }
            if arguments.contains("-chats") { state.opensChats = true }
            if arguments.contains("-requests") { state.opensMessageRequests = true }
            if arguments.contains("-moderation") { state.opensModeration = true }
            if let i = arguments.firstIndex(of: "-story") {
                state.opensAnyStory = true
                if i + 1 < arguments.count, !arguments[i + 1].hasPrefix("-") {
                    state.opensStoryOf = arguments[i + 1]
                }
            }
            if let i = arguments.firstIndex(of: "-profile") {
                let ad = (i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-")) ? arguments[i + 1] : nil
                state.opensProfileOf = .some(ad)
            }
            if arguments.contains("-paywall") { state.opensPaywall = true }
            if arguments.contains("-storyslow") { state.debugSlowStories = true }
            if let i = arguments.firstIndex(of: "-plan"), i + 1 < arguments.count {
                state.debugPaywallPlan = ["plus": SubscriptionTier.plus, "pro": .pro][arguments[i + 1]]
            }
            if arguments.contains("-pronote") { state.opensProNote = true }
            // `-badge founder`: kurucuya özel ekranları görmek için.
            if let i = arguments.firstIndex(of: "-badge"), i + 1 < arguments.count {
                let rozetler: [String: ProfileBadge] = ["founder": .founder, "moderator": .moderator, "none": .none]
                if let rozet = rozetler[arguments[i + 1]] {
                    state.myBadge = rozet
                    state.debugBadgeOverride = rozet
                }
            }
            // `-tier plus` / `-tier pro`: kademeye bağlı ekranları görmek için.
            if let i = arguments.firstIndex(of: "-tier"), i + 1 < arguments.count {
                let kademe = ["plus": SubscriptionTier.plus, "pro": .pro][arguments[i + 1]] ?? .free
                state.tier = kademe
                state.debugTierOverride = kademe
            }
            // Örnek veri modunda doğrudan uygulamaya giriyoruz. Eskiden açılış
            // yolu cihazda saklı oturum bayrağına bakıyordu; ekran görüntüsü
            // alırken bazen karşılama ekranı çıkıyor, bazen çıkmıyordu.
            if !onboarding { state.route = .app }
            if onboarding {
                let adlar: [String: AppState.OnboardingStep] = [
                    "identity": .identity, "interests": .interests,
                    "photo": .photo, "ready": .ready
                ]
                let istenen = arguments.firstIndex(of: "-onboarding")
                    .map { $0 + 1 }
                    .flatMap { $0 < arguments.count ? adlar[arguments[$0]] : nil }
                state.route = .onboarding(istenen ?? .identity)
                state.skipsSessionRestore = true
            }
            return state
        }
#endif
        return AppState()
    }

    init() {
        NavigationBarStyle.install()
        Self.configureRevenueCat()
        // Web/serverClientID olmadan `signInWithIdToken`'a giden id_token'ın audience'ı
        // Supabase'in Google provider ayarındaki Client ID ile eşleşmez ve doğrulama başarısız
        // olur — bkz. .env ve HANDOFF.md.
        let clientID = AppSecrets.googleClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverClientID = AppSecrets.googleServerClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !serverClientID.isEmpty else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: serverClientID)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onAppear { PushTokenStore.shared.bind(appState) }
                .onOpenURL { url in
                    // Üniversite e-postasındaki giriş bağlantısı bu şemayla geliyor
                    // (bkz. Info.plist, SupabaseProductService.requestEmailSignInLink).
                    // Google'ın kendi geri çağrısıyla karışmasın diye şemaya bakıyoruz.
                    if url.scheme == "bond", url.host == "edu-verified" {
                        // Doğrulama sayfasındaki "Uygulamaya dön" düğmesi.
                        Task { await appState.syncEduVerification() }
                    } else if url.scheme == "bond" {
                        Task { await appState.completeEmailSignIn(url: url) }
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
