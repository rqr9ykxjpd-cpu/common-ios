import SwiftUI

struct SocialFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var showStoryComposer = false
    @State private var showPostComposer = false
    @State private var selectedPeoplePlace: CampusPlace?
    @State private var selectedClub: CampusClub?
    @State private var showChats = false
    @State private var showNotifications = false
    @State private var showPlacesWall = false
    @State private var selectedPostAuthor: StudentProfile?

    /// Akış boşken iki ayrı durum var ve bunlar karıştırılmamalı: bir yer filtresi
    /// seçiliyken o noktada paylaşım olmaması, ile akışta gerçekten hiç gönderi olmaması.
    /// Önceden ikisine de "Bu noktadan henüz paylaşım yok" deniyor ve filtre seçili
    /// olmasa bile "Tüm akışı göster" düğmesi gösteriliyordu — o düğme hiçbir şey
    /// yapmıyordu. İlk kullanıcının gördüğü ilk ekran da burası.
    @ViewBuilder
    private var feedEmptyState: some View {
        if let place = appState.selectedPlaceFilter {
            AppEmptyState(
                systemImage: "mappin.slash",
                title: L10n.Feed.emptyPlace(place.name),
                actionTitle: L10n.Feed.showAll,
                action: { appState.selectedPlaceFilter = nil }
            )
        } else {
            AppEmptyState(
                systemImage: "photo.on.rectangle.angled",
                title: L10n.Feed.emptyTitle,
                message: L10n.Feed.emptyMessage,
                actionTitle: L10n.Feed.shareSomething,
                action: {
                    Haptics.impact(.light)
                    showPostComposer = true
                }
            )
        }
    }

    private var visiblePosts: [SocialPost] {
        guard let place = appState.selectedPlaceFilter else { return appState.posts }
        return appState.posts.filter { $0.place?.id == place.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear.frame(height: 1).id("feed-top")
                            storyRail
                            meetingPlaces
                            placeStrip
                            clubsSection
                            Divider().opacity(0.35).padding(.vertical, 14)
                            if visiblePosts.isEmpty, appState.isLoadingFeed {
                                // Yüklenirken "Akış henüz boş" yazıyordu; kullanıcı
                                // gönderisinin silindiğini sanabiliyordu.
                                AppLoadingView(message: L10n.Feed.loading)
                            } else if visiblePosts.isEmpty {
                                feedEmptyState
                            } else {
                                ForEach(visiblePosts) { post in
                                    PostCard(
                                        post: post,
                                        toggleLike: { appState.toggleLike(postID: post.id) },
                                        toggleSaved: { appState.toggleSaved(postID: post.id) },
                                        openProfile: { selectedPostAuthor = post.author },
                                        delete: { appState.deletePost(post.id) }
                                    )
                                    Divider().opacity(0.35).padding(.vertical, 20)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable { await appState.loadFeed(); await appState.loadStories() }
                    .onAppear {
                        proxy.scrollTo("feed-top", anchor: .top)
                    }
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            // Marka başlığı artık sistemin bar'ında duruyor: kaydırınca beliren
            // materyal, safe area ve geçişler iOS'a ait. Düğmelerin altındaki
            // elle çizilmiş daireler kaldırıldı — sistem kendi zeminini veriyor.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { akisAracCubugu }
            .fullScreenCover(isPresented: $showStoryComposer) {
                CreatePostView(initialContentType: 1)
            }
            .sheet(isPresented: $showPostComposer) {
                CreatePostView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .sheet(item: $selectedPeoplePlace) { place in
                PlacePeopleView(place: place)
            }
            .sheet(item: $selectedPostAuthor) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil)
                }
            }
            .sheet(item: $selectedClub) { club in
                ClubDetailView(club: club)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .fullScreenCover(isPresented: $showChats) {
                PremiumMatchesView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showPlacesWall) {
                PlacesWallView { place in appState.selectedPlaceFilter = place }
            }
            .task { await appState.loadFeed(); await appState.loadStories() }
#if DEBUG
            .task(id: appState.stories.count) {
                guard appState.opensAnyStory, appState.selectedStory == nil,
                      !appState.stories.isEmpty else { return }
                if let ad = appState.opensStoryOf {
                    appState.selectedStory = appState.stories.first {
                        $0.author.name.localizedCaseInsensitiveCompare(ad) == .orderedSame
                    }
                } else {
                    // Eşleşilmemiş biri: istek alanı yalnızca orada çıkıyor.
                    let sohbetler = Set(appState.conversations.map(\.profile.id))
                    appState.selectedStory = appState.stories.first {
                        !$0.isMine && !sohbetler.contains($0.author.id)
                    }
                }
            }
            .onAppear {
                if appState.opensComposer { showPostComposer = true }
                if appState.opensPlacesWall { showPlacesWall = true }
            }
            .fullScreenCover(item: Binding(
                get: { appState.opensProfileOf.map { DebugProfileRoute(name: $0) } },
                set: { if $0 == nil { appState.opensProfileOf = nil } }
            )) { rota in
                NavigationStack {
                    let kisi = rota.name.flatMap { ad in
                        appState.profiles.first { $0.name.localizedCaseInsensitiveCompare(ad) == .orderedSame }
                    } ?? appState.currentUserProfile
                    SocialPersonDetailView(profile: kisi, place: nil)
                }
            }
            .task(id: appState.clubs.count) {
                if appState.opensFirstClub, selectedClub == nil { selectedClub = appState.clubs.first }
            }
            .sheet(isPresented: Binding(get: { appState.opensPaywall }, set: { appState.opensPaywall = $0 })) {
                PaywallView()
            }
            .sheet(isPresented: Binding(get: { appState.opensProNote }, set: { appState.opensProNote = $0 })) {
                ProUpsellSheet().presentationDetents([.height(320)])
            }
#endif
            .fullScreenCover(item: Binding(get: { appState.selectedStory }, set: { appState.selectedStory = $0 })) { story in
                StoryViewer(
                    stories: appState.stories,
                    initialStoryID: story.id,
                    viewRecords: { storyID in
                        appState.stories.first(where: { $0.id == storyID })?.viewRecords ?? []
                    },
                    onViewed: { viewedStory in appState.markStoryViewed(viewedStory) },
                    onDelete: { storyID in appState.deleteStory(storyID) },
                    close: { appState.selectedStory = nil }
                )
            }
        }
    }


    private var storyRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                AddStoryBubble { showStoryComposer = true }
                // Story'ler gelene kadar şerit "kimse story atmamış" gibi
                // duruyordu. Yer tutucu daireler, gelmekte olduğunu gösteriyor.
                if appState.stories.isEmpty, appState.isLoadingStories {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(BondTheme.ink.opacity(0.07))
                                .frame(width: 62, height: 62)
                                .overlay { ProgressView().tint(BondTheme.muted).scaleEffect(0.7) }
                            Capsule()
                                .fill(BondTheme.ink.opacity(0.07))
                                .frame(width: 40, height: 9)
                        }
                    }
                }
                ForEach(appState.stories) { story in
                    Button {
                        appState.selectedStory = story
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                ProfileMedia(
                                    url: story.author.imageURL,
                                    data: nil,
                                    assetName: story.author.imageAssetName
                                )
                                    .frame(width: 47, height: 47)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().stroke(.white, lineWidth: 1)
                                    }
                                Circle()
                                    .stroke(
                                        story.viewed ? BondTheme.ink.opacity(0.14) : BondTheme.violet,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                    )
                                    .frame(width: 55, height: 55)
                                if let place = story.place {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white, BondTheme.violet)
                                        .offset(x: 17, y: 17)
                                        .accessibilityLabel(place.name)
                                }
                            }
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                            Text(story.author.name)
                                .font(.system(size: 11, weight: story.viewed ? .medium : .bold))
                                .foregroundStyle(BondTheme.ink.opacity(story.viewed ? 0.5 : 1))
                                .lineLimit(1)
                                .frame(width: 58)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    /// Akışta tek satır. Önceden başlık, "YER SEÇ" yazısı ve yatay kaydırılan
    /// çiplerden oluşan bir kart vardı: yerlerin çoğu ekrana sığmıyor, hangisinde
    /// kim olduğu görünmüyor ve kart akışta yer kaplıyordu. Artık dokununca yerlerin
    /// tamamının listelendiği duvar açılıyor.
    private var meetingPlaces: some View {
        Button {
            Haptics.impact(.light)
            showPlacesWall = true
        } label: {
            HStack(spacing: BondTheme.Space.md) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BondTheme.violet)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Feed.whereToMeet)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BondTheme.ink)
                    Text(subtitleForPlaces)
                        .font(.system(size: 12))
                        .foregroundStyle(appState.currentVisiblePlace == nil ? BondTheme.muted : BondTheme.violet)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(BondTheme.muted)
            }
            .padding(.horizontal, BondTheme.Space.md)
            .frame(minHeight: 62)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous).stroke(BondTheme.hairline))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// Yerlerin kısa şeridi. Duvarı açmak her seferinde iki dokunuş demek; en çok
    /// yapılan şey "şurada kim var?" diye bakmak, o yüzden buradan tek dokunuşla
    /// doğrudan o yerdeki kişiler açılıyor. Tamamı için sağdaki "Tümü".
    @ViewBuilder
    private var placeStrip: some View {
        if !appState.places.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.places.prefix(8)) { place in
                        Button {
                            Haptics.impact(.light)
                            selectedPeoplePlace = place
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: appState.currentVisiblePlace?.id == place.id ? "mappin.circle.fill" : "mappin")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(place.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(appState.currentVisiblePlace?.id == place.id ? BondTheme.paper : BondTheme.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .background(
                                appState.currentVisiblePlace?.id == place.id ? BondTheme.violet : BondTheme.ink.opacity(0.055),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Button {
                        Haptics.impact(.light)
                        showPlacesWall = true
                    } label: {
                        Text(L10n.Feed.allPlaces)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(BondTheme.violet)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .overlay(Capsule().stroke(BondTheme.violet.opacity(0.35)))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, 16)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.93),
                        .init(color: .black.opacity(0), location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .padding(.top, 8)
        }
    }

    private var subtitleForPlaces: String {
        if let active = appState.currentVisiblePlace { return L10n.Feed.visibleAt(active.name) }
        if let filter = appState.selectedPlaceFilter { return L10n.Feed.filteredBy(filter.name) }
        return L10n.Feed.placeCount(appState.places.count)
    }

    private var clubsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // "KATIL · TANIŞ · ÜRET" kaldırıldı: bir şey anlatmıyordu, yalnızca
            // başlığın yanını dolduruyordu.
            Text(L10n.Feed.clubsHeader)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(BondTheme.muted)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.clubs) { club in
                        Button { selectedClub = club } label: {
                            clubCard(club)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            // Sağdaki kart ekran kenarında sertçe kesiliyordu; yatay kaydırıldığı
            // anlaşılmıyor, bozuk sanılıyordu. İnce bir solma "devamı var" diyor.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.92),
                        .init(color: .black.opacity(0), location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        }
        .padding(.top, 14)
    }

    /// Daraltılmış kart. Önceden 210×166'lık, içinde ikon rozeti, kulüp adı, sonraki
    /// etkinlik, üye sayısı ve "Katıl" bağlantısı olan bir kutuydu; iki tanesi bile
    /// ekranı dolduruyordu. Artık ad, üye sayısı ve üyelik durumu — gerisi kulübe
    /// dokununca zaten açılıyor.

    /// Marka başlığı ve eylemler. Ayrı bir `ToolbarContentBuilder` olarak
    /// duruyor: gövdenin içine gömülünce derleyici tek ifadeyi makul sürede
    /// çözemiyor.
    @ToolbarContentBuilder private var akisAracCubugu: some ToolbarContent {
        // Marka `.navigationTitle` ile düz metin olarak veriliyordu; başlık
        // metnine yazı tipi verilemediği için logo değil etiket gibi duruyordu.
        // `.principal` öğesi olarak kendi görünümünü taşıyabiliyor.
        ToolbarItem(placement: .principal) {
            Wordmark()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                    if appState.unreadNotificationCount > 0 {
                Text("\(min(appState.unreadNotificationCount, 9))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(BondTheme.coral, in: Circle())
                    .offset(x: 8, y: -6)
                    }
                }
            }
            .accessibilityLabel(L10n.Feed.notificationsA11y(appState.unreadNotificationCount))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showChats = true } label: {
                Image(systemName: "message.fill")
            }
            .accessibilityLabel(L10n.Feed.chatsA11y)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showPostComposer = true } label: {
                Label(L10n.Feed.share, systemImage: "plus")
            }
            .accessibilityLabel(L10n.Feed.share)
        }
    }

    private func clubCard(_ club: CampusClub) -> some View {
        let joined = appState.isJoined(to: club)
        let accent = Color(hex: club.accentHex)
        return HStack(spacing: 9) {
            Image(systemName: club.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(accent, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(club.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(1)
                Text(joined ? L10n.Feed.member : L10n.Feed.memberCount(club.memberCount))
                    .font(.system(size: 11))
                    .foregroundStyle(joined ? accent : BondTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 52)
        .background(BondTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(joined ? accent.opacity(0.5) : BondTheme.hairline))
        .contentShape(Capsule())
    }

}

private struct AddStoryBubble: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(BondTheme.ink.opacity(0.08)).frame(width: 52, height: 52)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(BondTheme.ink.opacity(0.28)))
                        .clipShape(Circle())
                    Image(systemName: "plus")
                        .font(.caption2.bold()).foregroundStyle(BondTheme.onAccent)
                        .frame(width: 19, height: 19).background(BondTheme.acid, in: Circle())
                        .offset(x: -1, y: -1)
                }
                Text(L10n.Feed.yourStory).font(.system(size: 11, weight: .semibold)).foregroundStyle(BondTheme.ink)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

#if DEBUG
/// `-profile` bayrağının sunum kimliği.
struct DebugProfileRoute: Identifiable {
    let name: String?
    var id: String { name ?? "ben" }
}
#endif
