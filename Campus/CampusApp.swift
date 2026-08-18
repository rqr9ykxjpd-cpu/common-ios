import SwiftUI
import GoogleSignIn

@main
struct CampusApp: App {
    @State private var appState = CampusApp.initialState()

    /// Normalde gerçek servisle başlar. `-sample` argümanı verilirse (Xcode şeması
    /// veya `simctl launch ... -sample`) doğrudan örnek veriyle açılır — yalnızca DEBUG'da.
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
        // olur — bkz. Campus/Configuration.local.xcconfig ve SETUP.md.
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
#if DEBUG
                // Karşılama ekranındaki "Örnek veriyle gez" düğmesi bunu tetikler.
                // Tüm blok `#if DEBUG` içinde: Release derlemesinde ne düğme ne de
                // örnek veri servisi derleniyor.
                .onReceive(NotificationCenter.default.publisher(for: .campusUseSampleData)) { _ in
                    let sample = AppState(service: SampleProductService())
                    appState = sample
                    Task { await sample.restoreBackendSession() }
                }
#endif
        }
    }
}

#if DEBUG
extension Notification.Name {
    static let campusUseSampleData = Notification.Name("campus.useSampleData")
}
#endif
