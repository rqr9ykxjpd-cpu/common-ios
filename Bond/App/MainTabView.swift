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
                // Sekme simgesine eklenen efektler (zıplama vb.) çubuğa taşınmıyor:
                // iOS alt çubuğu yalnızca simgeyi ve yazıyı alıyor. Yeni mesajı rozet
                // gösteriyor; seçim animasyonunu iOS 26'nın cam çubuğu kendisi yapıyor.
                .tabItem { Label(L10n.CampusNavigation.chats, systemImage: "bubble.left.and.bubble.right") }
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
