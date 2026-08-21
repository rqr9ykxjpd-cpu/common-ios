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
        VStack(spacing: 10) {
            if let place = appState.selectedPlaceFilter {
                Image(systemName: "mappin.slash").font(.title2)
                Text("\(place.name) için henüz paylaşım yok.")
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.center)
                Button("Tüm akışı göster") { appState.selectedPlaceFilter = nil }
                    .font(.caption.bold())
                    .foregroundStyle(CampusTheme.violet)
            } else {
                Image(systemName: "photo.on.rectangle.angled").font(.title2)
                Text("Akış henüz boş.")
                    .font(.subheadline.bold())
                Text("İlk paylaşımı sen yapabilirsin.")
                    .font(.caption)
                    .foregroundStyle(CampusTheme.ink.opacity(0.45))
                Button {
                    Haptics.impact(.light)
                    showPostComposer = true
                } label: {
                    Text("BİR ŞEY PAYLAŞ")
                        .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                        .foregroundStyle(CampusTheme.paper)
                        .padding(.horizontal, 22).frame(height: 44)
                        .background(CampusTheme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
        }
        .foregroundStyle(CampusTheme.ink.opacity(0.55))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
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
                                VStack(spacing: 12) {
                                    ProgressView().tint(CampusTheme.violet)
                                    Text("Akış yükleniyor…")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(CampusTheme.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
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
            .background(CampusTheme.paper.ignoresSafeArea())
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
                    .presentationCornerRadius(30)
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
                    .presentationCornerRadius(30)
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
                                .fill(CampusTheme.ink.opacity(0.07))
                                .frame(width: 62, height: 62)
                                .overlay { ProgressView().tint(CampusTheme.muted).scaleEffect(0.7) }
                            Capsule()
                                .fill(CampusTheme.ink.opacity(0.07))
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
                                        story.viewed ? CampusTheme.ink.opacity(0.14) : CampusTheme.violet,
                                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                    )
                                    .frame(width: 55, height: 55)
                                if let place = story.place {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white, CampusTheme.violet)
                                        .offset(x: 17, y: 17)
                                        .accessibilityLabel(place.name)
                                }
                            }
                            .frame(width: 58, height: 58)
                            .contentShape(Circle())
                            Text(story.author.name)
                                .font(.system(size: 11, weight: story.viewed ? .medium : .bold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink.opacity(story.viewed ? 0.5 : 1))
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
            HStack(spacing: CampusTheme.Space.md) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CampusTheme.violet)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nerede tanışabiliriz?")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(CampusTheme.ink)
                    Text(subtitleForPlaces)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(appState.currentVisiblePlace == nil ? CampusTheme.muted : CampusTheme.violet)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CampusTheme.muted)
            }
            .padding(.horizontal, CampusTheme.Space.md)
            .frame(minHeight: 62)
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
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
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(appState.currentVisiblePlace?.id == place.id ? CampusTheme.paper : CampusTheme.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .background(
                                appState.currentVisiblePlace?.id == place.id ? CampusTheme.violet : CampusTheme.ink.opacity(0.055),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Button {
                        Haptics.impact(.light)
                        showPlacesWall = true
                    } label: {
                        Text("Tümü")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(CampusTheme.violet)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .overlay(Capsule().stroke(CampusTheme.violet.opacity(0.35)))
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
        if let active = appState.currentVisiblePlace { return "Şu an \(active.name) konumunda görünürsün" }
        if let filter = appState.selectedPlaceFilter { return "Akış: \(filter.name)" }
        return "\(appState.places.count) kampüs noktası"
    }

    private var clubsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // "KATIL · TANIŞ · ÜRET" kaldırıldı: bir şey anlatmıyordu, yalnızca
            // başlığın yanını dolduruyordu.
            Text("YÜ KULÜPLERİ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(CampusTheme.muted)
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
        ToolbarItem(placement: .topBarLeading) {
            Wordmark().foregroundStyle(CampusTheme.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                    if appState.unreadNotificationCount > 0 {
                Text("\(min(appState.unreadNotificationCount, 9))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(CampusTheme.coral, in: Circle())
                    .offset(x: 8, y: -6)
                    }
                }
            }
            .accessibilityLabel("Bildirimler, \(appState.unreadNotificationCount) okunmamış")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showChats = true } label: {
                Image(systemName: "message.fill")
            }
            .accessibilityLabel("Sohbetler")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showPostComposer = true } label: {
                Label("Paylaş", systemImage: "plus")
            }
            .accessibilityLabel("Paylaş")
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
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                    .lineLimit(1)
                Text(joined ? "Üyesin" : "\(club.memberCount) üye")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(joined ? accent : CampusTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 52)
        .background(CampusTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(joined ? accent.opacity(0.5) : CampusTheme.hairline))
        .contentShape(Capsule())
    }

}

private struct AddStoryBubble: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(CampusTheme.ink.opacity(0.08)).frame(width: 52, height: 52)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(CampusTheme.ink.opacity(0.28)))
                        .clipShape(Circle())
                    Image(systemName: "plus")
                        .font(.caption2.bold()).foregroundStyle(CampusTheme.onAccent)
                        .frame(width: 19, height: 19).background(CampusTheme.acid, in: Circle())
                        .offset(x: -1, y: -1)
                }
                Text("Hikâyen").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(CampusTheme.ink)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

struct PostCard: View {
    @Environment(AppState.self) private var appState
    let post: SocialPost
    let toggleLike: () -> Void
    let toggleSaved: () -> Void
    let openProfile: () -> Void
    let delete: () -> Void
    @State private var showComments = false
    @State private var showDeleteConfirmation = false

    /// Görselin gösterileceği yükseklik oranı (yükseklik = genişlik × bu değer).
    ///
    /// Fotoğrafın kendi oranı kullanılıyor; yalnızca uç değerler sınırlanıyor:
    /// çok geniş panoramalar şeride, çok uzun ekran görüntüleri de tek gönderiyle
    /// bütün akışı kaplayacak bir sütuna dönüşmesin diye. Sınırlar Instagram'ın
    /// kullandığı aralıkla aynı: 1.91:1 ile 4:5.
    private var displayAspect: CGFloat {
        let enGenis: CGFloat = 0.524   // 1.91:1
        // 1.34: telefonun kendi 4:3 dikey fotoğrafı tam sığsın. Instagram 1.25 (4:5)
        // kullanıyor ama o sınırda standart bir iPhone karesi hâlâ %6 kesiliyordu.
        let enUzun: CGFloat = 1.34
        guard let size = imageSize, size.width > 0 else { return 1 }
        return min(max(size.height / size.width, enGenis), enUzun)
    }

    /// Sunucudan gelen gönderilerde boyut ancak görsel indikten sonra bilinir;
    /// `ProfileMedia` yükleyince buraya yazıyor.
    @State private var remoteImageSize: CGSize?

    /// Başlığın ikinci satırı. Yer varsa yer, yoksa kişinin bölümü ve sınıfı.
    private var altSatir: String {
        if let place = post.place { return "\(place.name) · \(place.area)" }
        let parcalar = [post.author.department, post.author.year].filter { !$0.isEmpty }
        return parcalar.isEmpty ? post.author.university : parcalar.joined(separator: " · ")
    }

    private var imageSize: CGSize? {
        if let data = post.localImageData, let image = UIImage(data: data) { return image.size }
        if let name = post.imageAssetName, let image = UIImage(named: name) { return image.size }
        return remoteImageSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Button(action: openProfile) {
                    HStack(spacing: 11) {
                        ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text(post.author.name).font(.system(size: 14, weight: .bold, design: .rounded))
                                // Tik önceden koşulsuzdu: her gönderi yazarı doğrulanmış
                                // görünüyordu ve işaret hiçbir şey ifade etmiyordu.
                                ProfileBadgeLabel(badge: post.author.badge, compact: true)
                            }
                            // İkinci satır eskiden yalnızca gönderide yer varsa
                            // çıkıyordu; yer yokken 42 puntoluk yuvarlağın yanında
                            // tek satır kalıyor ve satır yüksekliği tutmuyordu.
                            // Yer yoksa bölüm ve sınıf yazılıyor, satır hep iki.
                            Text(altSatir)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(CampusTheme.ink.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(CampusTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(post.author.name) profilini aç")
                Spacer()
                Menu {
                    ShareLink(item: "\(post.author.name): \(post.caption)") {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                    if post.isMine {
                        Button("Gönderiyi sil", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                    if !post.isMine {
                        Menu {
                            ForEach(ReportReason.allCases) { reason in
                                Button(reason.title) { appState.report(post.author, reason: reason) }
                            }
                        } label: {
                            Label("Şikâyet et", systemImage: "flag")
                        }
                        Button("Kullanıcıyı engelle", role: .destructive) { appState.block(post.author) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(CampusTheme.ink.opacity(0.5))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)

            if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                // Görsel önceden sabit 0.72 orana (geniş format) zorlanıyordu. Dikey
                // çekilmiş bir fotoğraf bu kutuya sığmadığı için üstünden ve altından
                // kesiliyor, yüzün yarısı kayboluyordu. Artık fotoğrafın kendi oranı
                // kullanılıyor; yalnızca aşırı uçlar sınırlanıyor (bkz. displayAspect).
                // Yükseklik artık tek bir kaynaktan, kartın kendi genişliğinden
                // türetiliyor. Eskiden GeometryReader'ın içi kart genişliğini, dış
                // çerçevesi ise ekran genişliğini kullanıyordu; ikisi eşit olmadığı
                // her durumda görsel taşıp altındaki yazının üstüne biniyordu.
                Color.clear
                    .aspectRatio(1 / displayAspect, contentMode: .fit)
                    .overlay {
                        if post.localImageData != nil || post.imageAssetName != nil {
                            ProfileMedia(url: nil, data: post.localImageData,
                                         assetName: post.imageAssetName)
                        } else if let url = post.imageURL {
                            MeasuredRemoteImage(url: url, naturalSize: $remoteImageSize)
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: "Beğen") {
                        if !post.liked { toggleLike() }
                    }
            } else {
                Text(post.caption)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(CampusTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(CampusTheme.Space.xl)
                    .background(CampusTheme.acid.opacity(0.3))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if !post.liked { toggleLike() }
                    }
                    .accessibilityAction(named: "Beğen") {
                        if !post.liked { toggleLike() }
                    }
            }

            HStack(spacing: CampusTheme.Space.sm) {
                Button(action: toggleLike) {
                    Image(systemName: post.liked ? "heart.fill" : "heart")
                        .foregroundStyle(post.liked ? CampusTheme.coral : CampusTheme.ink)
                        .frame(width: 44, height: 44)
                }
                Button { showComments = true } label: { Image(systemName: "bubble.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Yorumları aç")
                ShareLink(item: "\(post.author.name): \(post.caption)") { Image(systemName: "paperplane").frame(width: 44, height: 44) }
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(post.saved ? CampusTheme.violet : CampusTheme.ink)
                        .frame(width: 44, height: 44)
                }
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(CampusTheme.ink)
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 7) {
                Text("\(post.likeCount) beğeni").font(.system(size: 12, weight: .bold, design: .rounded))
                if !post.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                    Text("**\(post.author.name)**  \(post.caption)")
                        .font(.system(size: 14, design: .rounded)).lineSpacing(3)
                }
                if !post.comments.isEmpty {
                    Button {
                        showComments = true
                    } label: {
                        Text(post.comments.count == 1 ? "1 yorumu gör" : "\(post.comments.count) yorumun tümünü gör")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CampusTheme.muted)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    ForEach(post.comments.suffix(2)) { comment in
                        Text("**\(comment.author)**  \(comment.body)")
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(CampusTheme.ink.opacity(0.62))
                    }
                }
                Text(post.createdAt.relativeTurkish)
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(CampusTheme.muted)
            }
            .foregroundStyle(CampusTheme.ink)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showComments) {
            CommentsView(postID: post.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .confirmationDialog("Gönderiyi sil?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Gönderiyi sil", role: .destructive, action: delete)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }
}

private struct CommentsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var draft = ""
    @State private var commentToDelete: SocialComment?
    @FocusState private var focused: Bool

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if post.comments.isEmpty {
                                ContentUnavailableView(
                                    "Henüz yorum yok",
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text("İlk yorumu sen yazabilirsin.")
                                )
                                .padding(.top, 64)
                            } else {
                                ForEach(post.comments) { comment in
                                    commentRow(comment)
                                }
                            }
                        }
                        .padding(.horizontal, CampusTheme.Space.lg)
                        .padding(.bottom, CampusTheme.Space.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                } else {
                    ContentUnavailableView("Gönderi bulunamadı", systemImage: "exclamationmark.bubble")
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Yorumlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                }
            }
            .confirmationDialog("Yorumu sil?", isPresented: Binding(
                get: { commentToDelete != nil },
                set: { if !$0 { commentToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Yorumu sil", role: .destructive) {
                    guard let commentToDelete else { return }
                    appState.deleteComment(commentToDelete.id, from: postID)
                    self.commentToDelete = nil
                }
                Button("Vazgeç", role: .cancel) { commentToDelete = nil }
            } message: {
                Text("Bu işlem geri alınamaz.")
            }
        }
    }

    private func commentRow(_ comment: SocialComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Fotoğraf varsa o, yoksa baş harf. Eskiden hep baş harf çiziliyordu
            // çünkü sorgu yalnızca adı getiriyordu.
            Group {
                if comment.authorAvatarURL != nil {
                    ProfileMedia(url: comment.authorAvatarURL, data: nil)
                } else {
                    Circle()
                        .fill(comment.isMine ? CampusTheme.acid : CampusTheme.violet.opacity(0.14))
                        .overlay {
                            Text(String(comment.author.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(comment.isMine ? CampusTheme.onAccent : CampusTheme.ink)
                        }
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.author)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(comment.createdAt.relativeTurkish)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                Text(comment.body)
                    .font(.system(size: 14, design: .rounded))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if comment.isMine {
                Menu {
                    Button("Yorumu sil", systemImage: "trash", role: .destructive) {
                        commentToDelete = comment
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Yorum seçenekleri")
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Yorum yaz...", text: $draft, axis: .vertical)
                .font(.system(size: 15, design: .rounded))
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(CampusTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button { send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CampusTheme.paper)
                    .frame(width: 44, height: 44)
                    .background(canSend ? CampusTheme.ink : CampusTheme.ink.opacity(0.22), in: Circle())
            }
            .disabled(!canSend)
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Yorumu gönder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private func send() {
        guard canSend else { return }
        appState.addComment(draft, to: postID)
        draft = ""
        focused = true
    }
}

struct StoryViewer: View {
    @Environment(AppState.self) private var appState
    let stories: [CampusStory]
    let viewRecords: (UUID) -> [StoryViewRecord]
    let onViewed: (CampusStory) -> Void
    let onDelete: (UUID) -> Void
    let close: () -> Void
    @State private var currentIndex: Int
    @State private var progress: CGFloat = 0
    @State private var reply = ""
    @State private var replySent = false
    @State private var sendingRequest = false
    @State private var liked = false
    @State private var showViewers = false
    @State private var isPaused = false
    @State private var pauseHintVisible = false
    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var selectedStoryAuthor: StudentProfile?
    @FocusState private var replyFocused: Bool

    init(stories: [CampusStory], initialStoryID: UUID, viewRecords: @escaping (UUID) -> [StoryViewRecord], onViewed: @escaping (CampusStory) -> Void, onDelete: @escaping (UUID) -> Void, close: @escaping () -> Void) {
        self.stories = stories
        self.viewRecords = viewRecords
        self.onViewed = onViewed
        self.onDelete = onDelete
        self.close = close
        _currentIndex = State(initialValue: stories.firstIndex(where: { $0.id == initialStoryID }) ?? 0)
    }

    private var story: CampusStory? {
        stories.indices.contains(currentIndex) ? stories[currentIndex] : nil
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let story {
                    ProfileMedia(url: story.imageURL, data: story.localImageData, assetName: story.imageAssetName)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    LinearGradient(colors: [.black.opacity(0.64), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle()).onTapGesture { previous() }
                        Color.clear.contentShape(Rectangle()).onTapGesture { next() }
                    }
                    .padding(.top, 90).padding(.bottom, 115)

                    VStack(spacing: 12) {
                        progressBars
                        storyHeader(story)
                        Spacer()
                        storyFooter(story)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                } else {
                    Button("Kapat", action: close).foregroundStyle(.white)
                }
            }
        }
        .task(id: currentIndex) {
            if let story {
                onViewed(story)
                liked = await appState.isStoryLiked(story.id)
            }
        }
        // `isPaused` anahtara dahil: bırakınca görev yeniden başlıyor ve ilerleme
        // kaldığı yerden devam ediyor.
        .task(id: "\(currentIndex)-\(replyFocused)-\(selectedStoryAuthor != nil)-\(isPaused)") { await playCurrentStory() }
        // Basılı tutunca duraklatma Plus'a özel. Ücretsizde basılı tutmak, bunun
        // bir özellik olduğunu gösteren ekranı açıyor.
        .onLongPressGesture(minimumDuration: 0.22, maximumDistance: 24) { } onPressingChanged: { basiliyor in
            guard appState.tier.canPauseStory else {
                // Hareketin ortasında modal açmak kullanıcıyı hapsediyordu:
                // story akıp giderken önüne tam ekran bir sayfa çıkıyor,
                // kapatması zorlaşıyordu. Bunun yerine story akmaya devam
                // ediyor ve engellemeyen bir ipucu beliriyor.
                if basiliyor {
                    withAnimation(.easeOut(duration: 0.15)) { pauseHintVisible = true }
                    Haptics.impact(.light)
                }
                return
            }
            withAnimation(.easeOut(duration: 0.15)) { isPaused = basiliyor }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task(id: pauseHintVisible) {
            guard pauseHintVisible else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.2)) { pauseHintVisible = false }
        }
        .sheet(item: $selectedStoryAuthor) { profile in
            NavigationStack {
                SocialPersonDetailView(profile: profile, place: nil)
            }
        }
        .sheet(isPresented: $showViewers) {
            if let story {
                StoryViewersSheet(story: story, records: viewRecords(story.id))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                // Story araya silinmiş olabilir; boş bir sayfa açmak yerine sebebini söylüyoruz.
                ContentUnavailableView("Story bulunamadı", systemImage: "eye.slash",
                                       description: Text("Story silinmiş ya da süresi dolmuş olabilir."))
                    .presentationDetents([.medium])
            }
        }
        .confirmationDialog("Story'yi sil?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            if let story, story.isMine {
                Button("Story'yi sil", role: .destructive) { onDelete(story.id) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }

    private var progressBars: some View {
        HStack(spacing: 4) {
            ForEach(stories.indices, id: \.self) { index in
                Capsule().fill(.white.opacity(0.3)).frame(height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(maxWidth: .infinity)
                            .scaleEffect(x: index < currentIndex ? 1 : (index == currentIndex ? progress : 0), anchor: .leading)
                    }
            }
        }
    }

    private func storyHeader(_ story: CampusStory) -> some View {
        HStack(spacing: 11) {
            Button { selectedStoryAuthor = story.author } label: {
                HStack(spacing: 11) {
                    ProfileMedia(url: story.author.imageURL, data: nil, assetName: story.author.imageAssetName)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(story.author.name).font(.subheadline.bold())
                        if let place = story.place {
                            Label(place.name, systemImage: "mappin").font(.caption).opacity(0.72)
                        }
                    }
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(story.author.name) profilini aç")
            Spacer()
            if story.isMine {
                Button { showViewers = true } label: {
                    // Göz işareti kaç *kişi* izlediğini gösteriyor: aynı kişinin tekrar
                    // izlemesi sayıyı artırmaz. Kaç kez izlendiği izleyici listesinde,
                    // kişi bazında ("3 kez") ve "Toplam izleme" özetinde duruyor.
                    Label("\(viewRecords(story.id).count)", systemImage: "eye.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                Menu {
                    Button("Story'yi sil", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
            }
            Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
        }
    }

    private func storyFooter(_ story: CampusStory) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if isPaused {
                Label("Duraklatıldı", systemImage: "pause.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(.black.opacity(0.35), in: Capsule())
                    .transition(.opacity)
            }

            // Ücretsiz kullanıcı basılı tuttuğunda: story durmuyor, akış
            // kesilmiyor; yalnızca özelliğin var olduğunu söyleyen bir ipucu.
            // Dokunursa Plus ekranı açılıyor — ama zorlamıyor.
            if pauseHintVisible {
                Button { showPaywall = true } label: {
                    Label("Duraklatma Pro'da", systemImage: "lock.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(CampusTheme.onAccent)
                        .padding(.horizontal, 11).frame(height: 28)
                        .background(CampusTheme.acid, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .transition(.opacity)
            }
            Text(story.caption).font(.system(size: 24, weight: .semibold, design: .rounded))
            if story.isMine {
                // Kendi story'ne yanıt yazma alanı çıkıyordu.
                EmptyView()
            } else if replySent {
                Label(conversation(with: story.author) == nil ? "İsteğin gönderildi" : "Yanıt gönderildi",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold()).foregroundStyle(CampusTheme.acid)
                    .frame(maxWidth: .infinity, alignment: .center).frame(height: 46)
            } else if conversation(with: story.author) == nil {
                // Eşleşme yoksa da yazabiliyorsun ama mesaj doğrudan düşmüyor:
                // karşı tarafa istek olarak gidiyor. Eşleşme şartını tamamen
                // kaldırmak istenmeyen mesaj yağmuru demekti; hiç yazdırmamak
                // ise utangaç kullanıcıyı susturuyordu.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Button { toggleStoryLike() } label: {
                            Image(systemName: liked ? "heart.fill" : "heart")
                                .font(.title3).foregroundStyle(liked ? CampusTheme.coral : .white)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(liked ? "Beğeniyi kaldır" : "Story'yi beğen")
                        TextField("İstek gönder...", text: $reply)
                            .focused($replyFocused)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(.black.opacity(0.2), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.55)))
                        Button { sendRequest() } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.title3).foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .opacity(reply.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                        }
                        .disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty || sendingRequest)
                        .accessibilityLabel("İsteği gönder")
                    }
                    // Ne olacağını önden söylüyoruz: kullanıcı mesajının
                    // doğrudan gittiğini sanıp cevap beklemesin.
                    Text("Eşleşmediniz. Mesajın istek olarak gider, kabul ederse sohbet açılır.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.leading, 4)
                }
            } else {
                HStack(spacing: 10) {
                    TextField("\(story.author.name) kişisine yanıtla...", text: $reply)
                        .focused($replyFocused)
                        .padding(.horizontal, 16).frame(height: 46)
                        .background(.black.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.55)))
                    Button { sendReply() } label: {
                        Image(systemName: reply.isEmpty ? "heart.fill" : "paperplane.fill")
                            .font(.title3).foregroundStyle(liked ? CampusTheme.coral : .white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(reply.isEmpty ? "Kalp gönder" : "Yanıtı gönder")
                }
            }
        }
    }

    @MainActor
    private func playCurrentStory() async {
        guard story != nil, !replyFocused, selectedStoryAuthor == nil, !isPaused else { return }

        let tick = Duration.milliseconds(50)
        let increment: CGFloat = 1 / 120
        while progress < 1 {
            do {
                try await Task.sleep(for: tick)
            } catch {
                return
            }
            guard !Task.isCancelled, !replyFocused, selectedStoryAuthor == nil, !isPaused else { return }
            progress = min(1, progress + increment)
        }
        guard !Task.isCancelled else { return }
        next()
    }

    private func prepareForTransition() {
        progress = 0
        reply = ""
        replySent = false
        liked = false
        replyFocused = false
    }

    private func previous() {
        prepareForTransition()
        if currentIndex > 0 { currentIndex -= 1 }
    }

    private func next() {
        prepareForTransition()
        if currentIndex < stories.count - 1 { currentIndex += 1 } else { close() }
    }

    private func conversation(with author: StudentProfile) -> Conversation? {
        appState.conversations.first(where: { $0.profile.id == author.id })
    }

    /// Yanıt, eşleştiğiniz sohbete gerçek bir mesaj olarak düşüyor.
    ///
    /// Eskiden bu fonksiyon hiçbir şey göndermiyordu: klavyeyi kapatıp
    /// "gönderildi" işaretini açıyor ve titreşim veriyordu. Kalp de yalnızca
    /// yerel bir değişkeni çeviriyordu. Kullanıcı yazdığını ulaştı sanıyor,
    /// karşı tarafa hiçbir şey gitmiyordu.
    private func sendRequest() {
        guard let story else { return }
        let metin = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !metin.isEmpty, !sendingRequest else { return }
        sendingRequest = true
        replyFocused = false
        Task {
            let oldu = await appState.sendMessageRequest(to: story.author, body: metin, storyID: story.id)
            sendingRequest = false
            guard oldu else { return }
            reply = ""
            withAnimation(.snappy) { replySent = true }
            Haptics.success()
        }
    }

    private func sendReply() {
        guard let story, let conversation = conversation(with: story.author) else { return }
        let metin = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        // Boş alanla kalbe basmak artık sohbete "❤️" mesajı göndermiyor; gerçek
        // bir story beğenisi bırakıyor ve sahibine bildirim gidiyor.
        guard !metin.isEmpty else { toggleStoryLike(); return }
        reply = ""
        replyFocused = false
        withAnimation(.snappy) { replySent = true }
        Haptics.success()
        Task { await appState.send(metin, in: conversation.id) }
    }

    /// Story beğenisi eşleşme gerektirmiyor: herkes beğenebilir, sahibi bildirim
    /// alır. Yazılı yanıt ise sohbete düştüğü için eşleşme şartına bağlı.
    private func toggleStoryLike() {
        guard let story, !story.isMine else { return }
        let yeni = !liked
        withAnimation(.snappy) { liked = yeni }
        appState.setStoryLiked(story.id, liked: yeni)
    }
}

private struct StoryViewersSheet: View {
    @Environment(AppState.self) private var appState
    @State private var showProNote = false
    let story: CampusStory
    let records: [StoryViewRecord]
    @Environment(\.dismiss) private var dismiss

    private var totalViews: Int { records.reduce(0) { $0 + $1.viewCount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: CampusTheme.Space.lg) {
                        summary(value: "\(records.count)", label: "Kişi")
                        if appState.tier.canSeeStoryViewCounts {
                            summary(value: "\(totalViews)", label: "Toplam izleme")
                        } else {
                            Button { showProNote = true } label: {
                                summary(value: "↑", label: "Toplam izleme")
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.bottom, CampusTheme.Space.lg)

                    if records.isEmpty {
                        ContentUnavailableView("Henüz izleyen yok", systemImage: "eye.slash", description: Text("Story izlendiğinde kişiler burada görünür."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, CampusTheme.Space.xxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(records.sorted(by: { $0.lastViewedAt > $1.lastViewedAt })) { record in
                                NavigationLink {
                                    SocialPersonDetailView(profile: record.viewer, place: nil)
                                } label: {
                                    HStack(spacing: CampusTheme.Space.md) {
                                        ProfileMedia(url: record.viewer.imageURL, data: nil, assetName: record.viewer.imageAssetName)
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.viewer.name)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            Text(record.lastViewedAt.relativeTurkish)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(CampusTheme.muted)
                                        }
                                        Spacer()
                                        // Kaç kez izlendiği Pro'ya özel. Kendi
                                        // izlemelerini herkes görebiliyor.
                                        if appState.tier.canSeeStoryViewCounts
                                            || record.viewer.id == appState.currentUserID {
                                            Text("\(record.viewCount) kez")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(CampusTheme.violet)
                                                .padding(.horizontal, 10)
                                                .frame(height: 30)
                                                .background(CampusTheme.violet.opacity(0.1), in: Capsule())
                                        } else {
                                            Button { showProNote = true } label: {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(CampusTheme.violet)
                                                    .frame(width: 30, height: 30)
                                                    .background(CampusTheme.violet.opacity(0.1), in: Circle())
                                            }
                                            .buttonStyle(PressableStyle())
                                            .accessibilityLabel("Kaç kez izlendiğini görmek için Pro gerekiyor")
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(CampusTheme.muted)
                                    }
                                    .foregroundStyle(CampusTheme.ink)
                                    .contentShape(Rectangle())
                                    .padding(.vertical, CampusTheme.Space.md)
                                    .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("\(record.viewer.name) profilini aç")
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Görüntüleyenler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
                }
            }
            .sheet(isPresented: $showProNote) {
                ProUpsellSheet().presentationDetents([.height(320)])
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 12, design: .rounded)).foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CampusTheme.Space.lg)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control).stroke(CampusTheme.hairline))
    }
}

/// Görseli kendimiz indiriyoruz ki gerçek boyutunu öğrenebilelim; `AsyncImage`
/// yalnızca bir `Image` veriyor, boyutunu okumanın yolu yok. Boyut olmadan
/// sunucudan gelen her gönderi kareye kırpılıyordu.
///
/// `URLSession.shared` kendi önbelleğini kullandığı için aynı görsel ikinci kez
/// gösterildiğinde ağa çıkılmıyor.
///
/// Boyut bir kapanışla değil `Binding` ile geri veriliyor: kapanış alanı taşıyan
/// bir görünümün yapıcısı ana iş parçacığına bağlanıyor ve izole olmayan
/// bağlamlardan çağrıldığında eşzamanlılık uyarısı üretiyor.
private struct MeasuredRemoteImage: View {
    let url: URL
    @Binding var naturalSize: CGSize?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                CampusTheme.ink.opacity(0.06)
            }
        }
        .task(id: url) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let indirilen = UIImage(data: data)
            else { return }
            image = indirilen
            naturalSize = indirilen.size
        }
    }
}

struct ProfileMedia: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        LinearGradient(colors: [CampusTheme.violet.opacity(0.9), CampusTheme.coral.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.35)))
    }
}

#if DEBUG
/// `-profile` bayrağının sunum kimliği.
struct DebugProfileRoute: Identifiable {
    let name: String?
    var id: String { name ?? "ben" }
}
#endif
