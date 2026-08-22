import SwiftUI

struct SocialProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showVisits = false
    @State private var showPaywall = false
    @State private var showPhoto = false
    @State private var enUstte = true
    @State private var showComposer = false
    @State private var showEditor = false
    @State private var showSettings = false
    /// Izgaradan açılan gönderi. Gönderiler tıklanabilir değildi: kendi
    /// paylaşımını açıp yorumlarını okumanın ya da silmenin yolu yoktu.
    @State private var selectedPost: SocialPost?

    private var displayName: String { appState.draft.name.isEmpty ? L10n.Common.you : appState.draft.name }
    private var department: String { appState.draft.department.isEmpty ? L10n.Profile.addDepartment : DepartmentCatalog.display(appState.draft.department) }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Profil içeriği ayarlardan ayrıldı. Kimlik ve üretimler bu sayfada,
                // hesap işlemleri native ayar sheet'inde yaşıyor.
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    identityHeader
                    completion
                    about
                    posts
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.sm)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            // Sayfanın burada bittiği sanılıyordu: gönderi yokken boş kart ekranı
            // dolduruyor ve altındaki bölümlerden hiçbiri görünmüyordu.
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, yeni in
                let ustte = yeni < 40
                if ustte != enUstte { withAnimation(.easeOut(duration: 0.2)) { enUstte = ustte } }
            }
            .overlay(alignment: .bottom) {
                if enUstte {
                    Button {
                        showSettings = true
                    } label: {
                        Label(L10n.Profile.moreSettings, systemImage: "gearshape")
                            .font(BondTheme.Typography.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.paper)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(BondTheme.ink, in: Capsule())
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                    }
                    .buttonStyle(PressableStyle())
                    // Sekme çubuğu kaydırma alanının üstüne çiziliyor; ipucu
                    // onun arkasında kalmasın diye yukarıda duruyor.
                    .padding(.bottom, 96)
                    .transition(.opacity)
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Tabs.profile)
            .navigationBarTitleDisplayMode(.inline)
            // Tam ekran: sekme çubuğu düzenleme ekranının üstüne binip alttaki
            // "Değişiklikleri kaydet" butonunu tıklanamaz hale getiriyordu.
            .fullScreenCover(isPresented: $showEditor) {
                NavigationStack { ProfileEditorView() }
            }
            .sheet(isPresented: $showSettings) {
                ProfileSettingsView()
            }
#if DEBUG
            .onAppear {
                if appState.opensCardPreview || appState.opensModeration {
                    showSettings = true
                }
            }
#endif
            .sheet(item: $selectedPost) { secili in
                // Kartın beğeni/kaydetme sonrası güncel kalması için gönderiyi anlık
                // listeden okuyoruz; `item` yalnızca hangisi olduğunu taşıyor.
                let guncel = appState.currentUserPosts.first(where: { $0.id == secili.id }) ?? secili
                NavigationStack {
                    ScrollView {
                        PostCard(
                            post: guncel,
                            toggleLike: { appState.toggleLike(postID: guncel.id) },
                            toggleSaved: { appState.toggleSaved(postID: guncel.id) },
                            openProfile: {},
                            delete: {
                                appState.deletePost(guncel.id)
                                selectedPost = nil
                            }
                        )
                        .padding(.vertical, BondTheme.Space.md)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.Common.close) { selectedPost = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showVisits) { ProfileVisitorsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fullScreenCover(isPresented: $showPhoto) {
                PhotoZoomView(url: appState.avatarURL, data: appState.avatarData)
            }
            .sheet(isPresented: $showComposer) { CreatePostView() }
        }
    }

    /// Kim olduğun. Önceden üç ayrı parçaydı: "Profil / Bond'da nasıl göründüğünü
    /// yönet" başlığı, avatar bloğu ve altta yüzen sayaçlar. Başlık ekranın ne olduğunu
    /// zaten belli olan bir şeyi tekrar ediyordu; sayaçlar ise tek kartsız bölüm olarak
    /// ortada duruyordu. Üçü birleşti.
    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
            HStack(alignment: .top, spacing: BondTheme.Space.lg) {
                // Fotoğrafa dokununca tam ekran açılıyor: 88 puntoluk bir daireden
                // fotoğrafın gerçekte nasıl göründüğü anlaşılmıyordu.
                Button { showPhoto = true } label: {
                    ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(BondTheme.hairline))
                }
                .buttonStyle(PressableStyle())
                .disabled(appState.avatarURL == nil && appState.avatarData == nil)
                .accessibilityLabel(L10n.Profile.zoomPhoto)

                VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                    Text(displayName)
                        .font(BondTheme.Typography.title2.weight(.bold))
                        .lineLimit(2)
                    Text("\(department) · \(AcademicYear.display(appState.draft.year))")
                        .font(BondTheme.Typography.subheadline)
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(2)
                    // Önceden herkeste "Doğrulanmış YÜ öğrencisi" yazıyordu; üniversite
                    // doğrulaması diye bir şey yok, yani herkes için yanlıştı.
                    ProfileBadgeLabel(badge: appState.myBadge)
                        .padding(.top, 2)
                    if let altSatir = appState.myBadge.subtitle {
                        // Aynı satır kişi kartında serif italik ve rozetin
                        // renginde duruyor; burada gri yuvarlak kalınca aynı
                        // hesap iki ekranda iki farklı kimlik gibi görünüyordu.
                        Text(altSatir)
                            .font(BondTheme.Typography.footnote)
                            .italic()
                            .foregroundStyle(appState.myBadge.accent)
                            .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }

            profileActions
        }
        .foregroundStyle(BondTheme.ink)
    }

    private var profileActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BondTheme.Space.sm) {
                postsStat
                visitorsStat
                Spacer(minLength: 0)
                editProfileButton
            }
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                postsStat
                visitorsStat
                editProfileButton
            }
        }
    }

    private var postsStat: some View {
        statPill(value: appState.currentUserPosts.count, label: L10n.Profile.statPosts)
    }

    private var visitorsStat: some View {
        // Üstteki rozet de aynı kilide tabi olmalı: ayarlardaki satırı
        // kilitleyip burayı açık bırakmak, kısıtı anlamsız kılıyordu.
        Button {
            if appState.tier.canSeeProfileVisitors { showVisits = true } else { showPaywall = true }
        } label: {
            statPill(value: appState.profileVisits.count, label: L10n.Profile.statVisitors)
        }
        .buttonStyle(PressableStyle())
    }

    private var editProfileButton: some View {
        Button { showEditor = true } label: {
            Text(L10n.Profile.edit)
                .font(BondTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(BondTheme.paper)
                .padding(.horizontal, 18)
                .frame(minHeight: 38)
                .background(BondTheme.ink, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(L10n.Profile.editA11y)
    }

    /// Sayaçlar artık ayrı bir bölüm değil, adın hemen altında küçük etiketler.
    private func statPill(value: Int, label: String) -> some View {
        HStack(spacing: BondTheme.Space.xs) {
            Text("\(value)")
                .font(BondTheme.Typography.subheadline.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(BondTheme.Typography.caption)
                .foregroundStyle(BondTheme.muted)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(BondTheme.ink.opacity(0.05), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Yalnızca eksikse ve tek satır. Önceden ekranın beşte birini kaplayan bir kart
    /// halinde her zaman duruyordu: yüzde, ilerleme çubuğu, iki satır açıklama ve bir
    /// bağlantı. Bu bir dürtme, ekranın kahramanı değil.
    @ViewBuilder
    private var completion: some View {
        if appState.profileCompletion < 100 {
            Button { showEditor = true } label: {
                HStack(spacing: BondTheme.Space.md) {
                    ZStack {
                        Circle().stroke(BondTheme.ink.opacity(0.1), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: Double(appState.profileCompletion) / 100)
                            .stroke(BondTheme.violet, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.Profile.completion(appState.profileCompletion))
                            .font(BondTheme.Typography.subheadline.weight(.semibold))
                        Text(L10n.Profile.completionHint)
                            .font(BondTheme.Typography.caption)
                            .foregroundStyle(BondTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BondTheme.muted)
                }
                .foregroundStyle(BondTheme.ink)
                .padding(.horizontal, BondTheme.Space.md)
                .frame(minHeight: 58)
                .background(BondTheme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    /// Kartsız. Bio senin kendi anlatın; sayfanın üstünde yüzen bir kutuya değil,
    /// doğrudan sayfaya ait. Kart sayısını azaltmak hiyerarşiyi geri getiriyor.
    private var about: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            Text(L10n.Profile.about)
                .font(BondTheme.Typography.headline)
                .foregroundStyle(BondTheme.ink)
            if appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(L10n.Profile.aboutPlaceholder)
                    .foregroundStyle(BondTheme.muted)
            } else {
                Text(appState.draft.bio)
                    .foregroundStyle(BondTheme.ink.opacity(0.82))
            }
            if !appState.draft.interests.isEmpty {
                FlowLayout(spacing: BondTheme.Space.sm) {
                    ForEach(appState.draft.interests.sorted(), id: \.self) { interest in
                        Text(InterestCatalog.displayName(interest))
                            .font(BondTheme.Typography.footnote.weight(.medium))
                            .foregroundStyle(BondTheme.ink)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(BondTheme.ink.opacity(0.055), in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .font(BondTheme.Typography.body)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var posts: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            AppSectionHeader(title: L10n.Profile.myPosts)
            if appState.currentUserPosts.isEmpty {
                ContentUnavailableView {
                    Label(L10n.Profile.firstPostHint, systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(L10n.Profile.firstPostBody)
                } actions: {
                    Button(L10n.Profile.shareCta) {
                        Haptics.impact(.light)
                        showComposer = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BondTheme.acid)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(appState.currentUserPosts) { post in
                        Button {
                            Haptics.impact(.light)
                            selectedPost = post
                        } label: {
                            // Hücre kare: yükseklik `aspectRatio(.fit)` ile hücrenin kendi
                            // genişliğinden türüyor. Eskiden `contentMode: .fill` vardı; o,
                            // görseli hücreden taşırıyor ve `clipped()` hücreye değil taşmış
                            // çerçeveye göre kestiği için gönderiler birbirinin üstüne
                            // biniyordu.
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                                        ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                                    } else {
                                        Text(post.caption)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(BondTheme.ink)
                                            .lineLimit(5)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .background(BondTheme.acid.opacity(0.35))
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }
}
