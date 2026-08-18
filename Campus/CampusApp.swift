import SwiftUI

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { _ in }
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
