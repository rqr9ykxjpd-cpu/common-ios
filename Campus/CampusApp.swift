import SwiftUI

@main
struct CampusApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { _ in }
        }
    }
}
