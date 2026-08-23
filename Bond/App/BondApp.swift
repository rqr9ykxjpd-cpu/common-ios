import SwiftUI
import GoogleSignIn
import RevenueCat

@main
struct BondApp: App {
    @State private var appState = BondApp.initialState()

    /// Normalde gerçek servisle başlar.
    ///
    /// Yalnızca DEBUG'da: `-sample` argümanı verilirse (Xcode şemasına eklenerek ya da
    /// `simctl launch ... -sample` ile) uygulama örnek veriyle açılır. Bu, sunucu
    /// olmadan ekranları gezmek ve geliştirirken doğrulama yapmak için. Arayüzde
    /// bunu tetikleyen bir düğme yok — kullanıcıya hiçbir yerde görünmez.
    private static func configureRevenueCat() {
        let key = AppSecrets.revenueCatAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, Purchases.isConfigured == false else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
    }

    private static func initialState() -> AppState {
        configureRevenueCat()
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-sample") {
            // `-onboarding` kayıt akışını baştan açar: örnek servis "sunucuda profil
            // yok" der, uygulama da gerçek yeni kullanıcıdaki gibi kayıt akışına
            // yönlendirir. Sunucu olmadan bu ekranları görmenin başka yolu yok.
            // İsteğe bağlı olarak adım adı verilebilir: `-onboarding ready`
            let onboarding = arguments.contains("-onboarding")
            let state = AppState(service: SampleProductService(hasProfile: !onboarding))
            // `-tab profile|discover|feed` doğrudan o sekmeyi açar. Ekranı görmeden
            // tasarım değiştirmek körlemesine çalışmak olurdu.
            if let index = arguments.firstIndex(of: "-tab"), index + 1 < arguments.count {
                state.initialTab = ["feed": 0, "discover": 1, "profile": 2][arguments[index + 1]] ?? 0
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
            if arguments.contains("-pronote") { state.opensProNote = true }
            if arguments.contains("-cardpreview") { state.opensCardPreview = true }
            // `-badge founder`: kurucuya özel ekranları görmek için.
            if let i = arguments.firstIndex(of: "-badge"), i + 1 < arguments.count {
                let rozetler: [String: ProfileBadge] = ["founder": .founder, "moderator": .moderator]
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
                    "identity": .identity, "preferences": .preferences,
                    "interests": .interests, "photo": .photo, "ready": .ready
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
                .onOpenURL { url in
                    // Üniversite e-postasındaki giriş bağlantısı bu şemayla geliyor
                    // (bkz. Info.plist, SupabaseProductService.requestEmailSignInLink).
                    // Google'ın kendi geri çağrısıyla karışmasın diye şemaya bakıyoruz.
                    if url.scheme == "bond" {
                        Task { await appState.completeEmailSignIn(url: url) }
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
