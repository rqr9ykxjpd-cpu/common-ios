import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            SocialFeedView()
                .tabItem { Label(L10n.Tabs.feed, systemImage: "house") }
                .tag(0)
            PlacesWallView(showsCloseButton: false) { place in
                appState.selectedPlaceFilter = place
                selection = 0
            }
                .tabItem { Label(L10n.CampusNavigation.places, systemImage: "mappin.and.ellipse") }
                .tag(1)
            PremiumMatchesView(showsCloseButton: false)
                .tabItem {
                    // Yeni mesaj/istek gelince ikon bir kez sekiyor: rozet
                    // rakamı küçük, hareket göz ucuyla fark ediliyor.
                    Label {
                        Text(L10n.CampusNavigation.chats)
                    } icon: {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .symbolEffect(.bounce, options: .nonRepeating, value: appState.chatActivityCount)
                    }
                }
                .badge(appState.chatActivityCount)
                .tag(2)
            SocialProfileView()
                .tabItem { Label(L10n.Tabs.profile, systemImage: "person") }
                .tag(3)
        }
        .tint(BondTheme.acid)
#if DEBUG
        .onAppear { selection = appState.initialTab }
#endif
    }
}
