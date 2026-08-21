import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            SocialFeedView()
                .tabItem { Label(L10n.Tabs.feed, systemImage: "house") }
                .tag(0)
            PremiumDiscoverView()
                .tabItem { Label(L10n.Tabs.discover, systemImage: "heart") }
                .tag(1)
            SocialProfileView()
                .tabItem { Label(L10n.Tabs.profile, systemImage: "person") }
                .tag(2)
        }
        .tint(BondTheme.acid)
#if DEBUG
        .onAppear { selection = appState.initialTab }
#endif
    }
}
