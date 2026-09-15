import SwiftUI

struct SocialFeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showStoryComposer = false
    @State private var showPostComposer = false
    /// Boş durumdan "ilk soruyu sen sor" ile açılınca composer o türle başlar.
    @State private var composerKind: PostKind = .moment
    /// Kurucu "oy ekle" alert'inin metni.
    @State private var boostInput = ""
    @State private var pinInput = ""
    @State private var showBadgeCatalog = false
    @State private var selectedClub: CampusClub?
    @State private var showNotifications = false
    @State private var showPlacesWall = false
    @State private var selectedPostAuthor: StudentProfile?
    @State private var showStudyGroupComposer = false
    /// Avatar → kişi kartı zoom geçişinin ad alanı.
    @Namespace private var profileZoom

    /// Akış boşken iki ayrı durum var ve bunlar karıştırılmamalı: bir yer filtresi
    /// seçiliyken o noktada paylaşım olmaması, ile akışta gerçekten hiç gönderi olmaması.
    /// Önceden ikisine de "Bu noktadan henüz paylaşım yok" deniyor ve filtre seçili
    /// olmasa bile "Tüm akışı göster" düğmesi gösteriliyordu — o düğme hiçbir şey
    /// yapmıyordu. İlk kullanıcının gördüğü ilk ekran da burası.
    @ViewBuilder
    private var feedEmptyState: some View {
        if let kind = appState.selectedKindFilter {
            // Tür seçiliyken boşluk bir davet: "Henüz soru yok — ilk soruyu sen sor".
            AppEmptyState(
                systemImage: kind.systemImage,
                title: kind.emptyTitle,
                actionTitle: kind.emptyAction,
                action: {
                    Haptics.impact(.light)
                    composerKind = kind
                    showPostComposer = true
                }
            )
        } else if let place = appState.selectedPlaceFilter {
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

    /// Sıra dondurulmuş: oy verince kart yerinden zıplamasın. Yeniden sıralama
    /// yalnızca gönderi kümesi, filtre ya da sıralama değişince (`rankKey`).
    @State private var rankedIDs: [UUID] = []

    private struct RankKey: Hashable {
        let ids: [UUID]
        let sort: FeedSort
        let kind: PostKind?
        let place: UUID?
        let version: Int
    }

    private var rankKey: RankKey {
        RankKey(ids: appState.posts.map(\.id), sort: appState.feedSort,
                kind: appState.selectedKindFilter, place: appState.selectedPlaceFilter?.id,
                version: appState.feedRankVersion)
    }

    private var visiblePosts: [SocialPost] {
        // Yükleme bitti ama `rerank` henüz koşmadıysa bir kare boş durum
        // görünmesin; o karede sıralamayı yerinde hesapla.
        guard !rankedIDs.isEmpty else { return filteredSorted() }
        let byID = Dictionary(appState.posts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return rankedIDs.compactMap { byID[$0] }
    }

    private func filteredSorted() -> [SocialPost] {
        let place = appState.selectedPlaceFilter
        let kind = appState.selectedKindFilter
        let suzulmus = appState.posts.filter { post in
            (place == nil || post.place?.id == place?.id) && (kind == nil || post.kind == kind)
        }
        // Önce sabitsiz sıra: az önce paylaşılanlar (yenileyene kadar), sonra sıralama.
        let taze = suzulmus.filter { !$0.isPinned && appState.justPublishedPostIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
        let digerleri = suzulmus.filter { !$0.isPinned && !appState.justPublishedPostIDs.contains($0.id) }
        var sira: [SocialPost]
        switch appState.feedSort {
        case .newest:
            sira = taze + digerleri.sorted { $0.createdAt > $1.createdAt }
        case .popular:
            // İki oturumda görülen gönderi ne kadar oy alırsa alsın görülmemişlerin altına.
            let seen = appState.seenCounts
            let puan = { (p: SocialPost) in p.popularityScore(seenCount: seen[p.id] ?? 0) }
            let (bikkin, canli) = digerleri.reduce(into: ([SocialPost](), [SocialPost]())) { acc, p in
                if (seen[p.id] ?? 0) >= 2 { acc.0.append(p) } else { acc.1.append(p) }
            }
            sira = taze + canli.sorted { puan($0) > puan($1) } + bikkin.sorted { puan($0) > puan($1) }
        }
        // Sabitler kendi sırasına oturur (1 = en üst); aynı sıradakiler arasında
        // son sabitlenen önce. Sıra listeden uzunsa sona eklenir.
        let sabitler = suzulmus.filter(\.isPinned).sorted {
            if $0.pinSlot != $1.pinSlot { return $0.pinSlot < $1.pinSlot }
            return ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast)
        }
        for sabit in sabitler {
            sira.insert(sabit, at: min(sabit.pinSlot - 1, sira.count))
        }
        return sira
    }

    private func rerank() { rankedIDs = filteredSorted().map(\.id) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear.frame(height: 1).id("feed-top")
                            storyRail
                            Divider().opacity(0.35).padding(.vertical, BondTheme.Space.md)
                            kindFilterRow
                            sortRow
                            studyGroupsSection
                            if let error = appState.feedError {
                                ScreenFailureView(message: error, compact: !visiblePosts.isEmpty) {
                                    Task { await appState.loadFeed() }
                                }
                                .padding(.horizontal, 20)
                            }
                            if visiblePosts.isEmpty, appState.isLoadingFeed {
                                // Yüklenirken "Akış henüz boş" yazıyordu; kullanıcı
                                // gönderisinin silindiğini sanabiliyordu.
                                AppLoadingView(message: L10n.Feed.loading)
                            } else if visiblePosts.isEmpty && appState.feedError == nil {
                                feedEmptyState
                            } else {
                                ForEach(visiblePosts) { post in
                                    PostCard(
                                        post: post,
                                        toggleLike: { appState.toggleLike(postID: post.id) },
                                        toggleSaved: { appState.toggleSaved(postID: post.id) },
                                        openProfile: { selectedPostAuthor = post.author },
                                        delete: { appState.deletePost(post.id) },
                                        zoomNamespace: profileZoom
                                    )
                                    .onAppear { appState.markPostSeen(post.id) }
                                    Divider().opacity(0.35).padding(.vertical, 14)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await appState.loadFeed()
                        await appState.loadStories()
                        await appState.loadStudyGroups(silently: true)
                    }
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
            .sheet(isPresented: $showStoryComposer) {
                CreatePostView(initialContentType: 1)
            }
            .sheet(isPresented: $showPostComposer, onDismiss: { composerKind = .moment }) {
                CreatePostView(initialKind: composerKind)
            }
            .sheet(isPresented: $showStudyGroupComposer) {
                StudyGroupComposer()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedPostAuthor) { profile in
                NavigationStack {
                    ProfilePhotoStackView(profile: profile)
                }
                .navigationTransition(.zoom(sourceID: profile.id, in: profileZoom))
            }
            .sheet(item: $selectedClub) { club in
                ClubDetailView(club: club)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .onChange(of: appState.opensNotifications) { _, open in
                guard open else { return }
                showNotifications = true
                appState.opensNotifications = false
            }
            .onAppear {
                if appState.opensNotifications {
                    showNotifications = true
                    appState.opensNotifications = false
                }
            }
            .sheet(isPresented: $showPlacesWall) {
                PlacesWallView { place in appState.selectedPlaceFilter = place }
            }
            // Açılışta oturum kurulurken görünüm yeniden kuruluyor ve SwiftUI bu
            // .task'ı iptal ediyordu: istek yarıda kesiliyor, iptal hata sayılmadığı
            // için akış "henüz boş" görünüyordu (yenileyene kadar). Yükleme, görünümün
            // iptalinden bağımsız bir görevde koşuyor.
            .task {
                await Task { @MainActor in
                    await appState.loadFeed()
                    await appState.loadStories()
                    await appState.loadStudyGroups(silently: true)
                }.value
            }
            .task(id: rankKey) { rerank() }
            .modifier(FounderPresentations(boostInput: $boostInput, pinInput: $pinInput))
#if DEBUG
            .modifier(DebugFeedLaunchHooks(
                showPostComposer: $showPostComposer,
                showPlacesWall: $showPlacesWall,
                selectedClub: $selectedClub
            ))
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
                    onAddStory: {
                        // Tam ekran kapanmadan sheet açılırsa sunum çakışıyor;
                        // önce izleyici kapanır, sonra composer.
                        appState.selectedStory = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showStoryComposer = true }
                    },
                    close: { appState.selectedStory = nil }
                )
            }
        }
    }


    /// "Tümü · Soru · Duyuru · …" — akışı kampüs panosuna çeviren filtre.
    private var kindFilterRow: some View {
        @Bindable var appState = appState
        return PostKindChipRow(
            selection: $appState.selectedKindFilter,
            allTitle: L10n.PostKind.all,
            kinds: PostKind.featured
        ) {
            MoreBadgesChip { showBadgeCatalog = true }
        }
        .padding(.bottom, BondTheme.Space.sm)
        .accessibilityLabel(L10n.PostKind.filterA11y)
        .sheet(isPresented: $showBadgeCatalog) {
            BadgeCatalogSheet(selection: $appState.selectedKindFilter, allowsClear: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    /// "Popüler ⌄" çiplerin altında, sola yaslı — kullanıcı tercihi.
    /// Sağda "Çalışma grubu kur": şu saatte şurada çalışacağım, gelen olur mu.
    private var sortRow: some View {
        HStack {
            sortChip
            Spacer()
            studyGroupButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, BondTheme.Space.xs)
    }

    private var studyGroupButton: some View {
        Button {
            Haptics.selection()
            showStudyGroupComposer = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "book.pages")
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.StudyGroup.create)
                    .font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .foregroundStyle(BondTheme.ink)
            .background(BondTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(L10n.StudyGroup.create)
    }

    /// Açık çalışma grupları: gönderilerin üstünde, yakın saat önce. Yoksa görünmez.
    @ViewBuilder private var studyGroupsSection: some View {
        if !appState.studyGroups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.StudyGroup.sectionTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BondTheme.muted)
                    .textCase(.uppercase)
                    .kerning(0.6)
                ForEach(appState.studyGroups) { group in
                    StudyGroupCard(group: group) { profile in
                        selectedPostAuthor = profile
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, BondTheme.Space.xs)
            .padding(.bottom, BondTheme.Space.md)
            .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: appState.studyGroups.map(\.id))
        }
    }

    /// "Popüler ⌄" — Reddit'teki sıralama menüsü.
    private var sortChip: some View {
        @Bindable var appState = appState
        return Menu {
            Picker(L10n.Board.sortA11y, selection: $appState.feedSort) {
                ForEach(FeedSort.allCases) { sort in
                    Label(sort.title, systemImage: sort.systemImage).tag(sort)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: appState.feedSort.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(appState.feedSort == .popular ? BondTheme.burntOrange : BondTheme.muted)
                Text(appState.feedSort.title)
                    .font(.footnote.weight(.semibold))
                    .contentTransition(.numericText())
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 4)
            .frame(height: 34)
            .foregroundStyle(BondTheme.muted)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Board.sortA11y)
        .accessibilityValue(appState.feedSort.title)
        .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: appState.feedSort)
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
                ForEach(appState.stories.filter { !$0.isMine }) { story in
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
                                        story.viewed ? BondTheme.ink.opacity(0.14) : BondTheme.burntOrange,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                    )
                                    .frame(width: 55, height: 55)
                                if story.isVideo {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 16, height: 16)
                                        .background(.black.opacity(0.55), in: Circle())
                                        .offset(x: -17, y: 17)
                                        .accessibilityHidden(true)
                                }
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
            .padding(.bottom, 4)
        }
    }

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
                // Rozet eskiden offset ile toolbar kapsülünün dışına taşıyordu;
                // kenar clip yüzünden kırmızı daire yarım görünüyordu. İkonun
                // etrafında boşluk bırakıp rozeti bu alanın içinde tutuyoruz.
                Image(systemName: "bell")
                    .padding(.top, 5)
                    .padding(.trailing, 7)
                    .overlay(alignment: .topTrailing) {
                        if appState.unreadNotificationCount > 0 {
                            Text("\(min(appState.unreadNotificationCount, 9))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(BondTheme.coral, in: Capsule())
                        }
                    }
            }
            .accessibilityLabel(L10n.Feed.notificationsA11y(appState.unreadNotificationCount))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showPostComposer = true
                } label: {
                    Label(L10n.Composer.post, systemImage: "square.and.pencil")
                }
                Button {
                    showStoryComposer = true
                } label: {
                    Label(L10n.Composer.story, systemImage: "circle.dashed")
                }
            } label: {
                Label(L10n.Feed.share, systemImage: "plus")
            }
            .accessibilityLabel(L10n.Feed.share)
        }
    }

}

private struct AddStoryBubble: View {
    @Environment(AppState.self) private var appState
    let action: () -> Void

    private var ownStory: CampusStory? {
        appState.stories.first(where: \.isMine)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    if let ownStory {
                        appState.selectedStory = ownStory
                    } else {
                        action()
                    }
                } label: {
                    ZStack {
                        ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                            .frame(width: 47, height: 47)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(.white, lineWidth: 1) }
                        Circle()
                            .stroke(
                                ownStory == nil ? BondTheme.ink.opacity(0.14) : BondTheme.burntOrange,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 55, height: 55)
                    }
                    .frame(width: 58, height: 58)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Feed.yourStory)

                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BondTheme.onAccent)
                        .frame(width: 19, height: 19)
                        .background(BondTheme.burntOrange, in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: -1, y: -1)
                .accessibilityLabel(L10n.Composer.shareStory)
            }
            Text(L10n.Feed.yourStory)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BondTheme.ink)
        }
    }
}

/// Kurucu sunumları tek yerden: kartın içindeki alert kaydırılmış hücrede
/// güvenilir açılmıyordu. AppState'teki hedef ID'yi izler.
private struct FounderPresentations: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var boostInput: String
    @Binding var pinInput: String

    private var boostTarget: SocialPost? {
        appState.boostPromptPostID.flatMap { id in appState.posts.first { $0.id == id } }
    }
    private var pinTarget: SocialPost? {
        appState.pinPromptPostID.flatMap { id in appState.posts.first { $0.id == id } }
    }

    func body(content: Content) -> some View {
        @Bindable var appState = appState
        content
            .alert(
                L10n.Board.boostTitle,
                isPresented: Binding(
                    get: { appState.boostPromptPostID != nil },
                    set: { if !$0 { appState.boostPromptPostID = nil } }
                ),
                presenting: boostTarget
            ) { post in
                TextField(L10n.Board.boostPlaceholder, text: $boostInput)
                    .keyboardType(.numbersAndPunctuation)
                Button(L10n.Board.boostApply) {
                    if let n = Int(boostInput.trimmed), n != 0 { appState.boostPost(post.id, extra: n) }
                    boostInput = ""
                }
                Button(L10n.Common.cancel, role: .cancel) { boostInput = "" }
            } message: { post in
                Text(post.boost > 0 ? "\(L10n.Board.boostPrompt)\n\(L10n.Board.boostCurrent(post.boost))" : L10n.Board.boostPrompt)
            }
            .alert(
                L10n.Board.pin,
                isPresented: Binding(
                    get: { appState.pinPromptPostID != nil },
                    set: { if !$0 { appState.pinPromptPostID = nil } }
                ),
                presenting: pinTarget
            ) { post in
                TextField(L10n.Board.pinPlaceholder, text: $pinInput)
                    .keyboardType(.numberPad)
                Button(L10n.Board.pinApply) {
                    let slot = Int(pinInput.trimmed) ?? 1
                    appState.setPostPin(post.id, slot: slot)
                    pinInput = ""
                }
                Button(L10n.Common.cancel, role: .cancel) { pinInput = "" }
            } message: { post in
                Text(post.isPinned ? "\(L10n.Board.pinPrompt)\n\(L10n.Board.pinnedAt(post.pinSlot))" : L10n.Board.pinPrompt)
            }
            .sheet(item: Binding(
                get: { appState.votersPostID.map(VotersRoute.init) },
                set: { if $0 == nil { appState.votersPostID = nil } }
            )) { route in
                PostVotersView(postID: route.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
    }
}

private struct VotersRoute: Identifiable { let id: UUID }

#if DEBUG
/// `-sample` lansman bayrakları. `body` içinde durunca derleyici ifade
/// süresini aşıyordu (type-check timeout).
private struct DebugFeedLaunchHooks: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var showPostComposer: Bool
    @Binding var showPlacesWall: Bool
    @Binding var selectedClub: CampusClub?

    func body(content: Content) -> some View {
        content
            .task(id: appState.stories.count) {
                guard appState.opensAnyStory, appState.selectedStory == nil,
                      !appState.stories.isEmpty else { return }
                if let ad = appState.opensStoryOf {
                    appState.selectedStory = appState.stories.first {
                        $0.author.name.localizedCaseInsensitiveCompare(ad) == .orderedSame
                    }
                } else {
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
            .sheet(item: debugProfileBinding) { rota in
                NavigationStack {
                    let kisi = rota.name.flatMap { ad in
                        SampleData.profiles.first { $0.name.localizedCaseInsensitiveCompare(ad) == .orderedSame }
                    } ?? appState.currentUserProfile
                    ProfilePhotoStackView(profile: kisi)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
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
    }

    private var debugProfileBinding: Binding<DebugProfileRoute?> {
        Binding(
            get: {
                guard let ad = appState.opensProfileOf else { return nil }
                if let ad, !SampleData.profiles.contains(where: {
                    $0.name.localizedCaseInsensitiveCompare(ad) == .orderedSame
                }) { return nil }
                return DebugProfileRoute(name: ad)
            },
            set: { if $0 == nil { appState.opensProfileOf = nil } }
        )
    }
}

/// `-profile` bayrağının sunum kimliği.
struct DebugProfileRoute: Identifiable {
    let name: String?
    var id: String { name ?? "ben" }
}
#endif
