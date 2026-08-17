import SwiftUI

struct PremiumDiscoverView: View {
    @Environment(AppState.self) private var appState
    @State private var drag: CGSize = .zero
    @State private var detailVisible = false
    @State private var showChats = false
    @State private var matchConversation: MatchConversationRoute?

    var body: some View {
        ZStack {
            CampusTheme.ink.ignoresSafeArea()
            GrainOverlay().ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if let profile = appState.profiles.first {
                    editorialCard(profile)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .offset(drag)
                        .rotationEffect(.degrees(Double(drag.width / 35)))
                        .contentShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.hero, style: .continuous))
                        .onTapGesture { detailVisible = true }
                        .gesture(swipeGesture)
                    controls
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 8)

        }
        .fullScreenCover(isPresented: $showChats) {
            PremiumMatchesView(close: { showChats = false })
        }
        .sheet(isPresented: $detailVisible) {
            if let profile = appState.profiles.first { ProfileDetailSheet(profile: profile) }
        }
        .fullScreenCover(item: Binding(get: { appState.currentMatch }, set: { appState.currentMatch = $0 })) { profile in
            MatchMomentView(profile: profile) {
                appState.currentMatch = nil
            } message: {
                let conversationID = appState.conversationID(for: profile)
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
                showChats = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "message.fill")
                    Text("Sohbetler")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(CampusTheme.ink)
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

    private func editorialCard(_ profile: StudentProfile) -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                    .frame(maxWidth: .infinity)
                    .frame(height: height * 0.64)
                    .clipped()

                    LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)

                    VStack {
                        HStack {
                            Label("%\(profile.compatibility) uyum", systemImage: "sparkles")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 11).frame(height: 30)
                                .background(.black.opacity(0.35), in: Capsule())
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(CampusTheme.acid)
                        }
                        Spacer()
                        HStack(alignment: .lastTextBaseline) {
                            Text(profile.name).font(.system(size: 35, weight: .bold, design: .rounded))
                            Text("\(profile.age)").font(.title3.weight(.medium))
                            Spacer()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label(profile.department, systemImage: "graduationcap.fill")
                        Spacer()
                        Text(profile.year)
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink.opacity(0.55))

                    Text(profile.bio)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(CampusTheme.ink.opacity(0.72))
                        .lineSpacing(3)
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        ForEach(profile.interests.prefix(3), id: \.self) { item in
                            Text(item)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 9)
                                .frame(height: 28)
                                .background(CampusTheme.ink.opacity(0.055), in: Capsule())
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(CampusTheme.ink)
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(CampusTheme.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            actionButton(icon: "xmark", label: "Geç", fill: .white.opacity(0.08), color: .white) { dismiss(-1) }
            Button { detailVisible = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.text.rectangle").font(.system(size: 17, weight: .bold))
                    Text("Profil").font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 72, height: 52)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
            actionButton(icon: "heart.fill", label: "Tanış", fill: CampusTheme.acid, color: CampusTheme.ink) { dismiss(1) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
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
            Image(systemName: "person.2.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(CampusTheme.acid)
            Text("Şimdilik hepsi bu.")
                .editorialTitle(40)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Yeni insanlar katıldıkça burada göreceksin.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            Text("Yeni öneriler olduğunda burada görünecek.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
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
                if let place = profile.visiblePlace { visiblePlace(place) }
                posts
                safetyActions
            }
            .padding(.bottom, CampusTheme.Space.xl)
        }
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) { decisionBar }
    }

    private var gallery: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedPhoto) {
                ForEach(Array(profile.galleryAssetNames.enumerated()), id: \.offset) { index, asset in
                    ProfileMedia(url: nil, data: nil, assetName: asset)
                        .frame(maxWidth: .infinity)
                        .frame(height: 460)
                        .clipped()
                        .tag(index)
                }
            }
            .frame(height: 460)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 5) {
                ForEach(profile.galleryAssetNames.indices, id: \.self) { index in
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
                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(CampusTheme.violet)
                }
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
                Label("Benzer kampüs planlarını seviyorsunuz", systemImage: "person.2.fill")
                Label("Ortak ilgi alanlarınız var", systemImage: "sparkles")
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
            Button("Şikâyet et", role: .destructive) { appState.toast = "Şikâyet alındı" }
            Button("Kullanıcıyı engelle", role: .destructive) { appState.toast = "Kullanıcı engellendi" }
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
                    AppSectionHeader(title: "Mesajlar")
                    if appState.conversations.isEmpty {
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

    private var newConnections: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Yeni bağlantılar")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CampusTheme.Space.md) {
                    ForEach(StudentProfile.samples) { profile in
                        NavigationLink {
                            SocialPersonDetailView(profile: profile, place: profile.visiblePlace)
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
                    Text(conversation.updatedAt.formatted(date: .omitted, time: .shortened))
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
                    Button("OTURUMU KAPAT") { appState.signOut() }
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
