import SwiftUI

struct SocialProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSaved = false
    @State private var showVisits = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showPaywall = false
    @State private var showModeration = false
    @State private var showPhoto = false
    @State private var enUstte = true
    @Environment(\.openURL) private var openURL
    @State private var showComposer = false
    @State private var showMeetingRequests = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditor = false
    @State private var showCardPreview = false
    /// Izgaradan açılan gönderi. Gönderiler tıklanabilir değildi: kendi
    /// paylaşımını açıp yorumlarını okumanın ya da silmenin yolu yoktu.
    @State private var selectedPost: SocialPost?

    private var displayName: String { appState.draft.name.isEmpty ? L10n.Common.you : appState.draft.name }
    private var department: String { appState.draft.department.isEmpty ? L10n.Profile.addDepartment : DepartmentCatalog.display(appState.draft.department) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                // Ekran dört bölgeye ayrıldı. Önceden dokuz bölüm vardı ve hepsi aynı
                // yuvarlak kartın içinde yüzüyordu — aynı köşe yarıçapı, aynı çerçeve,
                // aynı ağırlık. Hiyerarşi olmadığı için hiçbiri öne çıkmıyordu.
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    identityHeader      // kim olduğun
                    completion          // yalnızca eksikse
                    about               // kendi anlatın
                    posts               // ürettiklerin — ayarların üstünde
                    settingsList        // her şeyin yapıldığı tek liste
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.sm)
                .padding(.bottom, CampusTheme.Space.xxl)
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
                        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("hesabin", anchor: .top) }
                    } label: {
                        Label(L10n.Profile.moreSettings, systemImage: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(CampusTheme.paper)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(CampusTheme.ink, in: Capsule())
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                    }
                    .buttonStyle(PressableStyle())
                    // Sekme çubuğu kaydırma alanının üstüne çiziliyor; ipucu
                    // onun arkasında kalmasın diye yukarıda duruyor.
                    .padding(.bottom, 96)
                    .transition(.opacity)
                }
            }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // Tam ekran: sekme çubuğu düzenleme ekranının üstüne binip alttaki
            // "Değişiklikleri kaydet" butonunu tıklanamaz hale getiriyordu.
            .fullScreenCover(isPresented: $showEditor) {
                NavigationStack { ProfileEditorView() }
            }
            .sheet(isPresented: $showCardPreview) { OwnCardPreviewView() }
#if DEBUG
            .onAppear { if appState.opensCardPreview { showCardPreview = true } }
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
                        .padding(.vertical, CampusTheme.Space.md)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.Common.close) { selectedPost = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSaved) { savedPostsSheet.task { await appState.loadSavedPosts() } }
            .sheet(isPresented: $showVisits) { visitorsSheet }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fullScreenCover(isPresented: $showModeration) { ModerationView() }
#if DEBUG
            .onAppear { if appState.opensModeration { showModeration = true } }
#endif
            // Rozetli hesapta bekleyen şikayet sayısı satırda görünüyor.
            // Rozet oturum geri yüklendikten sonra geldiği için açılışa değil
            // rozetin kendisine bağlı: ekran açıldığında `isModerator` henüz
            // false oluyor ve sorgu hiç yapılmıyordu.
            .task(id: appState.myBadge) { await appState.loadReports() }
            .fullScreenCover(isPresented: $showPhoto) {
                PhotoZoomView(url: appState.avatarURL, data: appState.avatarData)
            }
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    LegalTextView(title: LegalDocumentRoute.kosullar.title, blocks: LegalDocumentRoute.kosullar.blocks)
                }
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    LegalTextView(title: LegalDocumentRoute.gizlilik.title, blocks: LegalDocumentRoute.gizlilik.blocks)
                }
            }
            .sheet(isPresented: $showComposer) { CreatePostView() }
            .sheet(isPresented: $showMeetingRequests) {
                MeetingRequestsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .alert(L10n.Profile.signOutConfirm, isPresented: $showSignOutAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Profile.signOut, role: .destructive) { Task { await appState.signOut() } }
            } message: {
                Text(L10n.Profile.signOutBody)
            }
            .alert(L10n.Profile.deleteConfirm, isPresented: $showDeleteAccountAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Profile.deleteAccount, role: .destructive) { Task { await appState.deleteAccount() } }
            } message: {
                Text(L10n.Profile.deleteBody)
            }
        }
    }

    /// Kim olduğun. Önceden üç ayrı parçaydı: "Profil / Common'da nasıl göründüğünü
    /// yönet" başlığı, avatar bloğu ve altta yüzen sayaçlar. Başlık ekranın ne olduğunu
    /// zaten belli olan bir şeyi tekrar ediyordu; sayaçlar ise tek kartsız bölüm olarak
    /// ortada duruyordu. Üçü birleşti.
    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
            HStack(alignment: .top, spacing: CampusTheme.Space.lg) {
                // Fotoğrafa dokununca tam ekran açılıyor: 88 puntoluk bir daireden
                // fotoğrafın gerçekte nasıl göründüğü anlaşılmıyordu.
                Button { showPhoto = true } label: {
                    ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CampusTheme.hairline))
                }
                .buttonStyle(PressableStyle())
                .disabled(appState.avatarURL == nil && appState.avatarData == nil)
                .accessibilityLabel(L10n.Profile.zoomPhoto)

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                    Text("\(department) · \(AcademicYear.display(appState.draft.year))")
                        .font(.system(size: 14))
                        .foregroundStyle(CampusTheme.muted)
                        .lineLimit(1)
                    // Önceden herkeste "Doğrulanmış YÜ öğrencisi" yazıyordu; üniversite
                    // doğrulaması diye bir şey yok, yani herkes için yanlıştı.
                    ProfileBadgeLabel(badge: appState.myBadge)
                        .padding(.top, 2)
                    if let altSatir = appState.myBadge.subtitle {
                        // Aynı satır kişi kartında serif italik ve rozetin
                        // renginde duruyor; burada gri yuvarlak kalınca aynı
                        // hesap iki ekranda iki farklı kimlik gibi görünüyordu.
                        Text(altSatir)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundStyle(appState.myBadge.accent)
                            .padding(.top, 1)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: CampusTheme.Space.sm) {
                statPill(value: appState.currentUserPosts.count, label: L10n.Profile.statPosts)
                // Üstteki rozet de aynı kilide tabi olmalı: ayarlardaki satırı
                // kilitleyip burayı açık bırakmak, kısıtı anlamsız kılıyordu.
                Button {
                    if appState.tier.canSeeProfileVisitors { showVisits = true } else { showPaywall = true }
                } label: {
                    statPill(value: appState.profileVisits.count, label: L10n.Profile.statVisitors)
                }
                .buttonStyle(PressableStyle())
                Spacer(minLength: 0)
                Button { showEditor = true } label: {
                    Text(L10n.Profile.edit)
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundStyle(CampusTheme.paper)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(CampusTheme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Profile.editA11y)
            }
        }
        .foregroundStyle(CampusTheme.ink)
    }

    /// Sayaçlar artık ayrı bir bölüm değil, adın hemen altında küçük etiketler.
    private func statPill(value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(CampusTheme.muted)
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(CampusTheme.ink.opacity(0.05), in: Capsule())
    }

    /// Yalnızca eksikse ve tek satır. Önceden ekranın beşte birini kaplayan bir kart
    /// halinde her zaman duruyordu: yüzde, ilerleme çubuğu, iki satır açıklama ve bir
    /// bağlantı. Bu bir dürtme, ekranın kahramanı değil.
    @ViewBuilder
    private var completion: some View {
        if appState.profileCompletion < 100 {
            Button { showEditor = true } label: {
                HStack(spacing: CampusTheme.Space.md) {
                    ZStack {
                        Circle().stroke(CampusTheme.ink.opacity(0.1), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: Double(appState.profileCompletion) / 100)
                            .stroke(CampusTheme.violet, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.Profile.completion(appState.profileCompletion))
                            .font(.system(size: 14, weight: .semibold))
                        Text(L10n.Profile.completionHint)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(CampusTheme.muted)
                }
                .foregroundStyle(CampusTheme.ink)
                .padding(.horizontal, CampusTheme.Space.md)
                .frame(minHeight: 58)
                .background(CampusTheme.violet.opacity(0.07), in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
    }

    /// Kartsız. Bio senin kendi anlatın; sayfanın üstünde yüzen bir kutuya değil,
    /// doğrudan sayfaya ait. Kart sayısını azaltmak hiyerarşiyi geri getiriyor.
    private var about: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            Text(L10n.Profile.about)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(CampusTheme.ink)
            if appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(L10n.Profile.aboutPlaceholder)
                    .foregroundStyle(CampusTheme.muted)
            } else {
                Text(appState.draft.bio)
                    .foregroundStyle(CampusTheme.ink.opacity(0.82))
            }
            if !appState.draft.interests.isEmpty {
                FlowLayout(spacing: 7) {
                    ForEach(appState.draft.interests.sorted(), id: \.self) { interest in
                        Text(InterestCatalog.displayName(interest))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CampusTheme.ink)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(CampusTheme.ink.opacity(0.055), in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .font(.system(size: 14))
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Profilden yapılan her şey tek listede. Önceden dört ayrı yüzen kart vardı
    /// (kart önizleme, buluşma istekleri, görünüm, hesap) ve aralarında üç düğmelik
    /// bir sıra. Hepsi aynı ağırlıkta olduğu için hiçbiri öne çıkmıyor, ekran da
    /// gereksiz uzuyordu.
    private var settingsList: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            // Bölüm başlıkları eklendi: sayfa başlıksız bir liste yığınıydı ve
            // aşağıda bir şey olduğu anlaşılmıyordu, kullanıcı hiç kaydırmıyordu.
            AppSectionHeader(title: L10n.Profile.yourAccount).id("hesabin")
            VStack(spacing: 0) {
                listRow(
                    icon: "rectangle.portrait.on.rectangle.portrait.angled",
                    title: L10n.Profile.cardHow,
                    detail: L10n.Profile.cardHowHint
                ) { showCardPreview = true }

                // Moderasyon yalnızca rozetli hesaplarda görünüyor. Şikayet
                // kutusu olmadan şikayetler hiçbir yere ulaşmıyordu.
                if appState.isModerator {
                    listDivider
                    listRow(icon: appState.pendingReports.isEmpty ? "shield" : "shield.fill",
                            title: L10n.Profile.reports,
                            detail: appState.pendingReports.isEmpty
                                ? L10n.Profile.reportsHint
                                : L10n.Profile.reportsWaiting(appState.pendingReports.count)) {
                        showModeration = true
                    }
                }

                listDivider
                listRow(icon: "bookmark", title: L10n.Profile.saved,
                        detail: L10n.Profile.savedHint) { showSaved = true }

                listDivider
                // Profiline bakanlar Plus'a özel. Satır gizlenmiyor: kilit,
                // özelliğin varlığını gösteriyor.
                listRow(icon: appState.tier.canSeeProfileVisitors ? "eye" : "lock.fill",
                        title: L10n.Profile.visitors,
                        detail: L10n.Profile.visitorsHint,
                        trailing: appState.tier.canSeeProfileVisitors
                            ? (appState.profileVisits.isEmpty ? nil : "\(appState.profileVisits.count)")
                            : L10n.Tier.plus) {
                    if appState.tier.canSeeProfileVisitors { showVisits = true } else { showPaywall = true }
                }

                listDivider
                listRow(icon: "cup.and.saucer", title: L10n.Profile.meetings,
                        detail: L10n.Profile.meetingsHint,
                        badge: appState.pendingIncomingMeetingRequestCount) { showMeetingRequests = true }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))

            // Görünüm ayrı duruyor: satır değil, seçim.
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Profile.appearanceSection)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(CampusTheme.muted)
                Picker(L10n.Profile.appearance, selection: $state.appearance) {
                    ForEach(AppState.Appearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, CampusTheme.Space.sm)


            AppSectionHeader(title: L10n.Profile.privacy)
            // Hayalet mod yalnızca Pro'da. Kilitliyken de görünüyor ki neyin
            // sunulduğu belli olsun.
            VStack(spacing: 0) {
                listRow(icon: appState.tier.hasGhostMode ? "eye.slash" : "lock.fill",
                        title: L10n.Profile.ghost,
                        detail: appState.tier.hasGhostMode
                            ? (appState.ghostMode
                                ? L10n.Profile.ghostOnDetail
                                : L10n.Common.off)
                            : L10n.Profile.ghostOffDetail,
                        trailing: appState.tier.hasGhostMode ? (appState.ghostMode ? L10n.Common.on : L10n.Common.off) : L10n.Tier.pro) {
                    if appState.tier.hasGhostMode {
                        appState.ghostMode.toggle()
                        Haptics.impact(.light)
                    } else {
                        showPaywall = true
                    }
                }
            }

            VStack(spacing: 0) {
                listRow(icon: "rectangle.portrait.and.arrow.right", title: L10n.Profile.signOut,
                        detail: L10n.Profile.signOutHint,
                        disabled: appState.isAccountActionInProgress) { showSignOutAlert = true }
                listDivider
                listRow(icon: "trash", title: L10n.Profile.deletePermanent,
                        detail: L10n.Profile.irreversible,
                        destructive: true,
                        disabled: appState.isAccountActionInProgress) { showDeleteAccountAlert = true }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
            .padding(.top, CampusTheme.Space.sm)

            AppSectionHeader(title: L10n.Profile.aboutSection)
            // En altta: hukuki metinler ikincil, sık kullanılan işlemleri aşağı
            // itmemeli. Koşullar eskiden yalnızca karşılama ekranındaydı, yani
            // giriş yaptıktan sonra bir daha ulaşılamıyordu.
            VStack(spacing: 0) {
                listRow(icon: "doc.text", title: L10n.Legal.terms,
                        detail: L10n.Profile.termsHint) { showTerms = true }
                listDivider
                listRow(icon: "hand.raised", title: L10n.Legal.privacy,
                        detail: L10n.Profile.privacyHint) { showPrivacy = true }
                listDivider
                // Kullanıcı içeriği olan uygulamalarda Apple ulaşılabilir bir
                // iletişim adresi arıyor; kullanıcının da bir sorun olduğunda
                // yazacak bir yeri olmalıydı.
                listRow(icon: "envelope", title: L10n.Profile.support,
                        detail: L10n.Profile.supportHint) {
                    guard let url = Self.destekURL else { return }
                    openURL(url)
                }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))

            if appState.isAccountActionInProgress {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.Profile.accountBusy)
                }
                .font(.caption)
                .foregroundStyle(CampusTheme.muted)
            }
        }
    }

    private var listDivider: some View {
        Divider().overlay(CampusTheme.hairline).padding(.leading, 58)
    }

    /// Liste satırı. İkonlar nötr: asit yeşili kartlar iki ayrı satırda kullanılıyordu
    /// ve marka rengi her yerde olunca vurgu olmaktan çıkıyordu.
    /// Destek adresi politika metinlerinde de yazan adresle aynı.
    private static let destekURL = URL(string: "mailto:220207018@yalova.edu.tr?subject=Common%20destek")

    private func listRow(
        icon: String,
        title: String,
        detail: String,
        trailing: String? = nil,
        badge: Int = 0,
        destructive: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: CampusTheme.Space.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(destructive ? CampusTheme.coral : CampusTheme.ink)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(destructive ? CampusTheme.coral : CampusTheme.ink)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(CampusTheme.muted)
                }
                Spacer(minLength: 0)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(CampusTheme.coral, in: Capsule())
                        .accessibilityLabel(L10n.Profile.badgeWaiting("\(badge)"))
                } else if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CampusTheme.muted)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CampusTheme.muted)
            }
            .padding(.horizontal, CampusTheme.Space.md)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var visitorsSheet: some View {
        NavigationStack {
            ScrollView {
                if appState.profileVisits.isEmpty {
                    ContentUnavailableView(
                        L10n.Profile.noVisitors,
                        systemImage: "eye",
                        description: Text(L10n.Profile.noVisitorsBody)
                    )
                    .padding(.top, CampusTheme.Space.xxl)
                } else {
                    LazyVStack(spacing: CampusTheme.Space.sm) {
                        // Satırlar düz metindi: profiline kimin baktığını görüyor ama
                        // o kişiye ulaşamıyordun.
                        ForEach(appState.profileVisits) { visit in
                            NavigationLink {
                                SocialPersonDetailView(profile: visit.profile, place: nil)
                            } label: {
                                HStack(spacing: CampusTheme.Space.md) {
                                    ProfileMedia(url: visit.profile.imageURL, data: nil, assetName: nil)
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 5) {
                                            Text(visit.profile.name)
                                                .font(.system(size: 15, weight: .bold))
                                            ProfileBadgeLabel(badge: visit.profile.badge, compact: true)
                                        }
                                        Text(DepartmentCatalog.display(visit.profile.department))
                                            .font(.system(size: 12))
                                            .foregroundStyle(CampusTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Text(visit.visitedAt.relativeTurkish)
                                        .font(.system(size: 11))
                                        .foregroundStyle(CampusTheme.muted)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(CampusTheme.ink.opacity(0.3))
                                }
                                .foregroundStyle(CampusTheme.ink)
                                .padding(CampusTheme.Space.md)
                                .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(CampusTheme.Space.lg)
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .refreshable { await appState.loadProfileVisits() }
            .task { await appState.loadProfileVisits() }
            .navigationTitle(L10n.Profile.visitors)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(L10n.Common.done) { showVisits = false } }
            }
        }
    }

    private var savedPostsSheet: some View {
        NavigationStack {
            ScrollView {
                if appState.savedPosts.isEmpty {
                    ContentUnavailableView(
                        L10n.Profile.noSaved,
                        systemImage: "bookmark",
                        description: Text(L10n.Profile.noSavedBody)
                    )
                    .padding(.top, CampusTheme.Space.xxl)
                } else {
                    LazyVStack(spacing: CampusTheme.Space.md) {
                        ForEach(appState.savedPosts) { post in
                            HStack(spacing: CampusTheme.Space.md) {
                                ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: nil)
                                    .frame(width: 64, height: 78)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.author.name)
                                        .font(.system(size: 14, weight: .bold))
                                    Text(post.caption)
                                        .font(.system(size: 13))
                                        .foregroundStyle(CampusTheme.muted)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    appState.toggleSaved(postID: post.id)
                                } label: {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(CampusTheme.violet)
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(L10n.Profile.unsave)
                            }
                            .padding(CampusTheme.Space.md)
                            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                        }
                    }
                    .padding(CampusTheme.Space.lg)
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Profile.saved)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(L10n.Common.done) { showSaved = false } }
            }
        }
    }

    @ViewBuilder
    private var posts: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: L10n.Profile.myPosts)
            if appState.currentUserPosts.isEmpty {
                AppSurface {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(CampusTheme.violet)
                        // El yazısı, sayfanın geri kalanının aksine bir davet gibi
                        // dursun: boş durum bir hata değil, bir başlangıç.
                        Text(L10n.Profile.firstPostHint)
                            .font(.custom("BradleyHandITCTT-Bold", size: 21))
                            .foregroundStyle(CampusTheme.coral)
                            .rotationEffect(.degrees(-1.5))
                        Text(L10n.Profile.firstPostBody)
                            .font(.system(size: 13))
                            .foregroundStyle(CampusTheme.muted)
                            .multilineTextAlignment(.center)
                        // Paylaşım düğmesi profilin tepesindeki üçlü sıradan kaldırıldı
                        // (akış başlığındaki "Paylaş" ile birebir aynı işi yapıyordu).
                        // Boş durumda burada durması hem daha yerinde hem keşfedilebilir.
                        Button {
                            Haptics.impact(.light)
                            showComposer = true
                        } label: {
                            Text(L10n.Profile.shareCta)
                                .font(.system(size: 11, weight: .black)).tracking(1)
                                .foregroundStyle(CampusTheme.paper)
                                .padding(.horizontal, 22).frame(height: 42)
                                .background(CampusTheme.ink, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
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
                                            .foregroundStyle(CampusTheme.ink)
                                            .lineLimit(5)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .background(CampusTheme.acid.opacity(0.35))
                                    }
                                }
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.control))
            }
        }
    }
}
