import SwiftUI
import GoogleSignIn

@main
struct CampusApp: App {
    @State private var appState = CampusApp.initialState()

    /// Normalde gerçek servisle başlar.
    ///
    /// Yalnızca DEBUG'da: `-sample` argümanı verilirse (Xcode şemasına eklenerek ya da
    /// `simctl launch ... -sample` ile) uygulama örnek veriyle açılır. Bu, sunucu
    /// olmadan ekranları gezmek ve geliştirirken doğrulama yapmak için. Arayüzde
    /// bunu tetikleyen bir düğme yok — kullanıcıya hiçbir yerde görünmez.
    private static func initialState() -> AppState {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-sample") {
            // `-onboarding` kayıt akışını baştan açar: örnek servis "sunucuda profil
            // yok" der, uygulama da gerçek yeni kullanıcıdaki gibi kayıt akışına
            // yönlendirir. Sunucu olmadan bu ekranları görmenin başka yolu yok.
            // İsteğe bağlı olarak adım adı verilebilir: `-onboarding ready`
            let onboarding = arguments.contains("-onboarding")
            let state = AppState(service: SampleProductService(hasProfile: !onboarding))
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
        // Web/serverClientID olmadan `signInWithIdToken`'a giden id_token'ın audience'ı
        // Supabase'in Google provider ayarındaki Client ID ile eşleşmez ve doğrulama başarısız
        // olur — bkz. Campus/Configuration.local.xcconfig ve HANDOFF.md.
        guard
            let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
            let serverClientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_SERVER_CLIENT_ID") as? String,
            !clientID.isEmpty, !serverClientID.isEmpty
        else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: serverClientID)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
    }
}
