import SwiftUI

struct PremiumDiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var drag: CGSize = .zero
    /// Karar eşiği geçildiğinde bir kez titreşim vermek için. Kullanıcı kartı
    /// bırakmadan önce "yeterince kaydırdım mı" diye kestirmek zorundaydı.
    @State private var pastThreshold = false
    @State private var detailVisible = false
    @State private var showChats = false
    @State private var showFilters = false
    @State private var matchConversation: MatchConversationRoute?

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if let profile = appState.profiles.first {
                    ZStack {
                        DiscoveryCard(profile: profile, highlightedInterests: appState.draft.interests)
                            // Kararın rengi kartın tamamına yayılıyor: damga küçük ve
                            // köşede kalıyordu, kaydırırken göz kartın ortasında oluyor.
                            .overlay {
                                RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous)
                                    .fill(drag.width > 0 ? CampusTheme.acid : CampusTheme.coral)
                                    .opacity(0.3 * swipeProgress)
                                    .allowsHitTesting(false)
                            }
                            .overlay(alignment: .top) {
                                HStack {
                                    decisionStamp("TANIŞ", color: CampusTheme.acid, rotation: -12)
                                        .opacity(drag.width > 0 ? swipeProgress : 0)
                                    Spacer()
                                    // Eskiden beyazdı: iki karar da aynı renkteydi ve
                                    // hangisinin ne olduğu yalnızca yazıdan anlaşılıyordu.
                                    decisionStamp("GEÇ", color: CampusTheme.coral, rotation: 12)
                                        .opacity(drag.width < 0 ? swipeProgress : 0)
                                }
                                .padding(20)
                            }
                            .offset(drag)
                            .rotationEffect(.degrees(Double(drag.width / 35)))
                            .contentShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous))
                            .onTapGesture { detailVisible = true }
                            .gesture(swipeGesture)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    swipeHint
                    controls
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 8)

        }
        .task {
            if appState.profiles.isEmpty { await appState.loadDiscovery(reset: true) }
            await appState.loadConversations()
        }
        .fullScreenCover(isPresented: $showChats) {
            PremiumMatchesView(close: { showChats = false })
        }
        .sheet(isPresented: $showFilters) {
            DiscoveryFilterSheet(filters: appState.discoveryFilters) { filters in
                Task { await appState.applyDiscoveryFilters(filters) }
            }
        }
        .sheet(isPresented: $detailVisible) {
            if let profile = appState.profiles.first { ProfileDetailSheet(profile: profile) }
        }
        .fullScreenCover(item: Binding(get: { appState.currentMatch }, set: { appState.currentMatch = $0 })) { profile in
            MatchMomentView(profile: profile) {
                appState.currentMatch = nil
            } message: { starter in
                // Eşleşme anında sohbet zaten gerçek eşleşme kimliğiyle açılıyor.
                guard let conversationID = appState.conversationID(for: profile) else {
                    appState.currentMatch = nil
                    return
                }
                if let starter { Task { await appState.send(starter, in: conversationID) } }
                appState.currentMatch = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    matchConversation = MatchConversationRoute(id: conversationID)
                }
            }
        }
        .fullScreenCover(item: $matchConversation) { route in
            NavigationStack { ConversationView(conversationID: route.id) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tanış")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("YÜ'den yeni biriyle tanış")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                showFilters = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.1), in: Circle())
                    if appState.discoveryFilters.activeCount > 0 {
                        Text("\(appState.discoveryFilters.activeCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(CampusTheme.onAccent)
                            .frame(width: 17, height: 17)
                            .background(CampusTheme.acid, in: Circle())
                    }
                }
                .accessibilityLabel(appState.discoveryFilters.activeCount > 0
                    ? "Filtreler, \(appState.discoveryFilters.activeCount) aktif"
                    : "Filtreler")
            }
            .buttonStyle(PressableStyle())
            Button {
                Haptics.impact(.light)
                showChats = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "message.fill")
                    Text("Sohbetler")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(CampusTheme.onAccent)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(CampusTheme.acid, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .zIndex(10)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(height: 62)
    }


    /// Kaydırma sırasında kararın ne yönde olduğunu gösterir. Sürükleme hareketi vardı ama
    /// hiçbir görsel karşılığı yoktu; kullanıcı kartı bırakana kadar ne olacağını bilmiyordu.
    private var swipeProgress: CGFloat {
        min(abs(drag.width) / 110, 1)
    }

    private func decisionStamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color, lineWidth: 3))
            .rotationEffect(.degrees(rotation))
    }

    /// Kaydırmanın ne yaptığı hiçbir yerde yazmıyordu. Kaydırırken o yönün metni
    /// öne çıkıyor, böylece bilgi ilk denemede de kararın ortasında da veriliyor.
    private var swipeHint: some View {
        HStack(spacing: 8) {
            Label("Sola kaydır: geç", systemImage: "arrow.left")
                .foregroundStyle(drag.width < 0
                                 ? CampusTheme.coral
                                 : .white.opacity(0.4))
            Text("·").foregroundStyle(.white.opacity(0.25))
            Label("Sağa kaydır: tanış", systemImage: "arrow.right")
                .foregroundStyle(drag.width > 0
                                 ? CampusTheme.acid
                                 : .white.opacity(0.4))
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .animation(.easeOut(duration: 0.15), value: drag.width > 0)
        .animation(.easeOut(duration: 0.15), value: drag.width < 0)
        .padding(.top, 12)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            // "Geri al" kaldırıldı: kararlar sunucuya yazılıyor ve geri alınamıyordu,
            // buton backend modunda her zaman pasifti.
            actionButton(icon: "xmark", label: "Geç", fill: .white.opacity(0.08), color: .white) { dismiss(-1) }
            actionButton(icon: "heart.fill", label: "Tanış", fill: CampusTheme.acid, color: CampusTheme.ink) { dismiss(1) }

            iconButton(systemName: "person.text.rectangle", tint: .white) { detailVisible = true }
                .accessibilityLabel("Profilin tamamını gör")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func iconButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CampusTheme.line))
        }
        .buttonStyle(PressableStyle())
    }

    private func actionButton(icon: String, label: String, fill: Color, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(CampusTheme.line))
        }
        .buttonStyle(PressableStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            if appState.isLoadingDiscovery {
                ProgressView().tint(CampusTheme.acid)
                Text("Öneriler hazırlanıyor").foregroundStyle(.white)
            } else if let error = appState.discoveryError {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(CampusTheme.coral)
                Text(error).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                Button("Tekrar dene") { Task { await appState.loadDiscovery(reset: true) } }
                    .foregroundStyle(CampusTheme.acid)
            } else {
                let activeFilters = appState.discoveryFilters.activeCount
                Image(systemName: activeFilters > 0 ? "line.3.horizontal.decrease.circle" : "person.2.slash")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(CampusTheme.acid)
                Text(activeFilters > 0 ? "Filtrelerine uyan\nkimse kalmadı." : "Şimdilik hepsi bu.")
                    .editorialTitle(38)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Liste boş kalınca sebebin filtreler mi yoksa gerçekten kimsenin olmaması mı
                // olduğu anlaşılmıyordu; kullanıcı filtreyi daralttığını unutmuş olabilir.
                if activeFilters > 0 {
                    Text("\(activeFilters) filtren açık. Gevşetirsen daha fazla kişi görürsün.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button {
                            Haptics.impact(.light)
                            Task { await appState.applyDiscoveryFilters(DiscoveryFilters()) }
                        } label: {
                            Text("FİLTRELERİ TEMİZLE")
                                .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                                .foregroundStyle(CampusTheme.onAccent)
                                .padding(.horizontal, 22).frame(height: 46)
                                .background(CampusTheme.acid, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        Button("Filtreleri düzenle") { showFilters = true }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    Text("Yeni insanlar katıldıkça burada göreceksin.\nYenilersen daha önce geçtiklerin de tekrar çıkar.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                    Button {
                        Haptics.impact(.light)
                        Task { await appState.reloadDiscoveryIncludingPasses() }
                    } label: {
                        Label("Yenile", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(CampusTheme.acid)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                let asildi = abs(value.translation.width) > 100
                if asildi != pastThreshold {
                    pastThreshold = asildi
                    if asildi { Haptics.impact(.light) }
                }
            }
            .onEnded { value in
                abs(value.translation.width) > 100 ? dismiss(value.translation.width > 0 ? 1 : -1) : withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) { drag = .zero }
            }
    }

    private func dismiss(_ direction: CGFloat) {
        guard let profile = appState.profiles.first else { return }
        Haptics.impact(direction > 0 ? .medium : .light)
        withAnimation(.easeIn(duration: 0.24)) { drag = CGSize(width: direction * 650, height: 20) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            drag = .zero
            Task { await appState.react(to: profile, liked: direction > 0) }
        }
    }
}

struct ProfileDetailSheet: View {
    let profile: StudentProfile
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto = 0

    private var profilePosts: [SocialPost] {
        appState.posts.filter { $0.author.name == profile.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                gallery
                identity
                compatibility
                interests
                posts
                safetyActions
            }
            .padding(.bottom, CampusTheme.Space.xl)
        }
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) { decisionBar }
    }

    private var galleryPageCount: Int {
        max(profile.galleryImageURLs.count, 1)
    }

    private var gallery: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedPhoto) {
                if profile.galleryImageURLs.isEmpty {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: nil)
                        .frame(maxWidth: .infinity)
                        .frame(height: 460)
                        .clipped()
                        .tag(0)
                } else {
                    ForEach(Array(profile.galleryImageURLs.enumerated()), id: \.offset) { index, url in
                        ProfileMedia(url: url, data: nil, assetName: nil)
                            .frame(maxWidth: .infinity)
                            .frame(height: 460)
                            .clipped()
                            .tag(index)
                    }
                }
            }
            .frame(height: 460)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 5) {
                ForEach(0..<galleryPageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPhoto ? .white : .white.opacity(0.42))
                        .frame(width: index == selectedPhoto ? 20 : 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.black.opacity(0.28), in: Capsule())
            .padding(.top, 14)
            .padding(.trailing, 66)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .accessibilityLabel("Kapat")
            .buttonStyle(PressableStyle())
            .padding(14)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(profile.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("\(profile.age)")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                ProfileBadgeLabel(badge: profile.badge, compact: true)
                Spacer()
                Text("%\(profile.compatibility) uyum")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.violet)
            }
            Label("\(profile.department) · \(profile.year)", systemImage: "graduationcap.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
            Text(profile.bio)
                .font(.system(size: 16, design: .rounded))
                .lineSpacing(4)
        }
        .padding(.horizontal, CampusTheme.Space.lg)
    }

    private var compatibility: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: "Neden uyumlusunuz?")
                ForEach(profile.compatibilityReasons, id: \.self) { reason in
                    Label(reason, systemImage: "sparkles")
                }
                if !profile.activeLabel.isEmpty {
                    Label(profile.activeLabel, systemImage: "clock")
                }
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, CampusTheme.Space.lg)
    }


    private var interests: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "İlgi alanları")
            HStack(spacing: CampusTheme.Space.sm) {
                ForEach(profile.interests, id: \.self) { interest in
                    Text(interest)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(CampusTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(CampusTheme.hairline))
                }
            }
        }
        .padding(.horizontal, CampusTheme.Space.lg)
    }

    private func visiblePlace(_ place: CampusPlace) -> some View {
        HStack(spacing: CampusTheme.Space.md) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(CampusTheme.violet)
                .frame(width: 40, height: 40)
                .background(CampusTheme.violet.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Şu an görünür")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
        }
        .padding(.horizontal, CampusTheme.Space.lg)
    }

    @ViewBuilder
    private var posts: some View {
        if !profilePosts.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: "Paylaşımları")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CampusTheme.Space.sm) {
                        ForEach(profilePosts) { post in
                            ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                                .frame(width: 150, height: 188)
                                .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                        }
                    }
                }
            }
            .padding(.horizontal, CampusTheme.Space.lg)
        }
    }

    private var safetyActions: some View {
        Menu {
            Menu {
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) { appState.report(profile, reason: reason) }
                }
            } label: {
                Label("Şikâyet et", systemImage: "flag")
            }
            Button("Kullanıcıyı engelle", role: .destructive) { appState.block(profile) }
        } label: {
            Label("Güvenlik seçenekleri", systemImage: "shield")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
        }
        .padding(.horizontal, CampusTheme.Space.lg)
    }

    private var decisionBar: some View {
        HStack(spacing: CampusTheme.Space.md) {
            AppButton(title: "Geç", systemName: "xmark", role: .secondary) { react(liked: false) }
            AppButton(title: "Tanış", systemName: "heart.fill", role: .accent) { react(liked: true) }
        }
        .padding(.horizontal, CampusTheme.Space.lg)
        .padding(.vertical, CampusTheme.Space.md)
        .background(CampusTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private func react(liked: Bool) {
        dismiss()
        Task { await appState.react(to: profile, liked: liked) }
    }
}

struct PremiumMatchesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var close: (() -> Void)?

    init(close: (() -> Void)? = nil) {
        self.close = close
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    header
                    newConnections
                    meetSuggestions
                    AppSectionHeader(title: "Mesajlar")
                    if appState.conversations.isEmpty, appState.isLoadingConversations {
                        // Yüklenirken "henüz sohbetin yok" yazıyordu.
                        VStack(spacing: 12) {
                            ProgressView().tint(CampusTheme.violet)
                            Text("Sohbetler yükleniyor…")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(CampusTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else if appState.conversations.isEmpty {
                        emptyConversations
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.conversations.sorted(by: { $0.updatedAt > $1.updatedAt })) { conversation in
                                NavigationLink {
                                    ConversationView(conversationID: conversation.id)
                                } label: {
                                    conversationRow(conversation)
                                }
                                .buttonStyle(PressableStyle())
                                Divider().overlay(CampusTheme.hairline)
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .refreshable { await appState.loadConversations() }
            .task {
                // Kullanıcı Tanış sekmesine hiç uğramadan buraya gelebilir; o durumda
                // aday listesi boş olur ve öneri şeridi hiç görünmezdi.
                if appState.profiles.isEmpty { await appState.loadDiscovery() }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sohbetler")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Eşleşmelerin ve mesajların")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
            Spacer()
            AppIconButton(systemName: "xmark") { close?() ?? dismiss() }
        }
    }

    /// Sohbeti olan kişiler. Hiç yoksa bölüm tamamen gizleniyor: eskiden boş bir
    /// başlık ve altında bomboş bir şerit kalıyordu.
    @ViewBuilder private var newConnections: some View {
        if !appState.conversations.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: "Yeni bağlantılar")
                circleStrip(appState.conversations.map(\.profile))
            }
        }
    }

    /// Henüz sohbet etmediğin, tanışabileceğin kişiler. Uygulamaya yeni katılanlar
    /// da buraya düşüyor: gizlilik kuralı gereği bir hesap gönderi paylaşana kadar
    /// doğrudan okunamıyor, tanışma adayları ise sunucudaki
    /// `get_discovery_candidates` üzerinden geldiği için yeni hesaplar görünebiliyor.
    @ViewBuilder private var meetSuggestions: some View {
        let sohbetEdilenler = Set(appState.conversations.map(\.profile.id))
        let oneriler = appState.profiles.filter { !sohbetEdilenler.contains($0.id) }
        if !oneriler.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: "Tanışabileceklerin")
                circleStrip(Array(oneriler.prefix(12)))
            }
        }
    }

    private func circleStrip(_ profiles: [StudentProfile]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CampusTheme.Space.md) {
                ForEach(profiles) { profile in
                    NavigationLink {
                        SocialPersonDetailView(profile: profile, place: nil)
                    } label: {
                        VStack(spacing: 7) {
                            ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                                .frame(width: 68, height: 68)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CampusTheme.violet, lineWidth: 2))
                            Text(profile.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: CampusTheme.Space.md) {
            ProfileMedia(url: conversation.profile.imageURL, data: nil, assetName: conversation.profile.imageAssetName)
                .frame(width: 54, height: 54)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.profile.name)
                        .font(.system(size: 15, weight: conversation.unreadCount > 0 ? .bold : .semibold, design: .rounded))
                    Spacer()
                    Text(conversation.updatedAt.shortTimeTurkish)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                HStack {
                    Text(conversation.lastMessage)
                        .font(.system(size: 13, weight: conversation.unreadCount > 0 ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(conversation.unreadCount > 0 ? CampusTheme.ink : CampusTheme.muted)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(CampusTheme.violet, in: Circle())
                    }
                }
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.vertical, CampusTheme.Space.md)
        .contentShape(Rectangle())
    }

    private var emptyConversations: some View {
        VStack(spacing: CampusTheme.Space.sm) {
            Image(systemName: "message")
                .font(.title2)
                .foregroundStyle(CampusTheme.muted)
            Text("Henüz mesajın yok")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Biriyle eşleştiğinde sohbetin burada görünür.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CampusTheme.Space.xxl)
    }
}

struct DiscoveryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DiscoveryFilters
    let apply: (DiscoveryFilters) -> Void
    private let years = ["Hazırlık", "1. sınıf", "2. sınıf", "3. sınıf", "4. sınıf", "Lisansüstü"]
    private let departments = ["Psikoloji", "Endüstri Mühendisliği", "İşletme", "Bilgisayar Mühendisliği", "Hukuk"]

    init(filters: DiscoveryFilters, apply: @escaping (DiscoveryFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Yaş aralığı") {
                    Stepper("En az \(draft.minimumAge)", value: $draft.minimumAge, in: 18...draft.maximumAge)
                    Stepper("En fazla \(draft.maximumAge)", value: $draft.maximumAge, in: draft.minimumAge...99)
                }
                Section("Sınıf") {
                    ForEach(years, id: \.self) { year in
                        toggleRow(year, selected: draft.academicYears.contains(year)) {
                            toggle(year, in: &draft.academicYears)
                        }
                    }
                }
                Section("Bölüm") {
                    ForEach(departments, id: \.self) { department in
                        toggleRow(department, selected: draft.departments.contains(department)) {
                            toggle(department, in: &draft.departments)
                        }
                    }
                }
                Section("Öncelikler") {
                    Toggle("En az bir ortak ilgi", isOn: $draft.requiresCommonInterest)
                    Toggle("Yalnızca aynı kampüs", isOn: $draft.campusOnly)
                }
            }
            .navigationTitle("Tanış filtreleri")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") { apply(draft); dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Spacer(); if selected { Image(systemName: "checkmark").foregroundStyle(CampusTheme.violet) } }
        }.foregroundStyle(CampusTheme.ink)
    }

    private func toggle(_ value: String, in values: inout Set<String>) {
        if values.contains(value) { values.remove(value) } else { values.insert(value) }
    }
}

private struct MatchConversationRoute: Identifiable {
    let id: UUID
}

struct PremiumProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
        ZStack {
            CampusTheme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack { Wordmark(compact: true); Spacer(); Eyebrow(text: "profil / 84%", color: CampusTheme.ink.opacity(0.5)) }
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [CampusTheme.violet, CampusTheme.coral], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(height: 260)
                        Text("S").font(.system(size: 210, weight: .medium, design: .serif)).foregroundStyle(.white.opacity(0.72)).offset(x: 18, y: 38)
                        Text("CEM\n21").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white).padding(18)
                    }.clipped()

                    Text("Profilin, senden önce\no konuşur.").editorialTitle(37).foregroundStyle(CampusTheme.ink)

                    VStack(spacing: 0) {
                        NavigationLink { ProfileEditorView() } label: { settingsRow("01", "Hikâyeni düzenle", "person.text.rectangle") }
                        settingsRow("02", "Tanışmak istediğin kişi", "scope")
                        settingsRow("03", "Güvenlik ve doğrulama", "checkmark.shield")
                    }
                    Button("OTURUMU KAPAT") { Task { await appState.signOut() } }
                        .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(CampusTheme.ink.opacity(0.4))
                }
                .padding(22).padding(.bottom, 90)
            }
        }
        }
    }

    private func settingsRow(_ number: String, _ title: String, _ icon: String) -> some View {
        HStack(spacing: 14) {
            Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(CampusTheme.ink.opacity(0.4))
            Image(systemName: icon).frame(width: 22)
            Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer(); Image(systemName: "arrow.right").font(.caption)
        }
        .foregroundStyle(CampusTheme.ink).padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.ink.opacity(0.14)).frame(height: 1) }
    }
}
