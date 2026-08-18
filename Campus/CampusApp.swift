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
        if ProcessInfo.processInfo.arguments.contains("-sample") {
            return AppState(service: SampleProductService())
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
