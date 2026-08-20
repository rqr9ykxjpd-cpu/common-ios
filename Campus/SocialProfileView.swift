import SwiftUI

struct SocialProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSaved = false
    @State private var showVisits = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showComposer = false
    @State private var showMeetingRequests = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditor = false
    @State private var showCardPreview = false
    /// Izgaradan açılan gönderi. Gönderiler tıklanabilir değildi: kendi
    /// paylaşımını açıp yorumlarını okumanın ya da silmenin yolu yoktu.
    @State private var selectedPost: SocialPost?

    private var displayName: String { appState.draft.name.isEmpty ? "Cem" : appState.draft.name }
    private var department: String { appState.draft.department.isEmpty ? "Bölümünü ekle" : appState.draft.department }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Ekran dört bölgeye ayrıldı. Önceden dokuz bölüm vardı ve hepsi aynı
                // yuvarlak kartın içinde yüzüyordu — aynı köşe yarıçapı, aynı çerçeve,
                // aynı ağırlık. Hiyerarşi olmadığı için hiçbiri öne çıkmıyordu.
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    identityHeader      // kim olduğun
                    completion          // yalnızca eksikse
                    about               // kendi anlatın
                    settingsList        // her şeyin yapıldığı tek liste
                    posts               // ürettiklerin
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.sm)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            // Tam ekran: sekme çubuğu düzenleme ekranının üstüne binip alttaki
            // "Değişiklikleri kaydet" butonunu tıklanamaz hale getiriyordu.
            .fullScreenCover(isPresented: $showEditor) {
                NavigationStack { ProfileEditorView() }
            }
            .sheet(isPresented: $showCardPreview) { OwnCardPreviewView() }
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
                            Button("Kapat") { selectedPost = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSaved) { savedPostsSheet.task { await appState.loadSavedPosts() } }
            .sheet(isPresented: $showVisits) { visitorsSheet }
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    LegalTextView(title: "Kullanım Koşulları", blocks: LegalTexts.kosullar)
                }
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    LegalTextView(title: "Gizlilik Politikası", blocks: LegalTexts.gizlilik)
                }
            }
            .sheet(isPresented: $showComposer) { CreatePostView() }
            .sheet(isPresented: $showMeetingRequests) {
                MeetingRequestsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
            .alert("Çıkış yapılsın mı?", isPresented: $showSignOutAlert) {
                Button("Vazgeç", role: .cancel) {}
                Button("Çıkış yap", role: .destructive) { Task { await appState.signOut() } }
            } message: {
                Text("Hesabın silinmez. Tekrar giriş yaptığında profilin kaldığı yerden devam eder.")
            }
            .alert("Hesap kalıcı olarak silinsin mi?", isPresented: $showDeleteAccountAlert) {
                Button("Vazgeç", role: .cancel) {}
                Button("Hesabımı sil", role: .destructive) { Task { await appState.deleteAccount() } }
            } message: {
                Text("Profil, mesajlar, gönderiler, fotoğraflar ve bu cihazdaki hesap verileri silinir. Bu işlem geri alınamaz.")
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
                ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(CampusTheme.hairline))

                VStack(alignment: .leading, spacing: 5) {
                    Text(displayName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text("\(department) · \(appState.draft.year)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                        .lineLimit(1)
                    // Önceden herkeste "Doğrulanmış YÜ öğrencisi" yazıyordu; üniversite
                    // doğrulaması diye bir şey yok, yani herkes için yanlıştı.
                    ProfileBadgeLabel(badge: appState.myBadge)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: CampusTheme.Space.sm) {
                statPill(value: appState.currentUserPosts.count, label: "gönderi")
                Button { showVisits = true } label: {
                    statPill(value: appState.profileVisits.count, label: "ziyaretçi")
                }
                .buttonStyle(PressableStyle())
                Spacer(minLength: 0)
                Button { showEditor = true } label: {
                    Text("DÜZENLE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(CampusTheme.paper)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(CampusTheme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Profili düzenle")
            }
        }
        .foregroundStyle(CampusTheme.ink)
    }

    /// Sayaçlar artık ayrı bir bölüm değil, adın hemen altında küçük etiketler.
    private func statPill(value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, design: .rounded))
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
                        Text("Profilin %\(appState.profileCompletion) tamam")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Eksikleri tamamla, keşifte daha çok görün")
                            .font(.system(size: 12, design: .rounded))
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
            Text("Hakkımda")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(CampusTheme.ink)
            if appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Kendinden, kampüste sevdiğin şeylerden veya tanışmak istediğin insanlardan kısaca bahset.")
                    .foregroundStyle(CampusTheme.muted)
            } else {
                Text(appState.draft.bio)
                    .foregroundStyle(CampusTheme.ink.opacity(0.82))
            }
            if !appState.draft.interests.isEmpty {
                ProfileFlowLayout(spacing: 7) {
                    ForEach(appState.draft.interests.sorted(), id: \.self) { interest in
                        Text(interest)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CampusTheme.ink)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(CampusTheme.ink.opacity(0.055), in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .font(.system(size: 14, design: .rounded))
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
            VStack(spacing: 0) {
                listRow(
                    icon: "rectangle.portrait.on.rectangle.portrait.angled",
                    title: "Kartın nasıl görünüyor?",
                    detail: "Tanış'ta karşı tarafın gördüğü hali — buradan düzenleyebilirsin"
                ) { showCardPreview = true }

                listDivider
                listRow(icon: "bookmark", title: "Kaydedilenler",
                        detail: "Sonra bakmak için işaretlediklerin") { showSaved = true }

                listDivider
                listRow(icon: "eye", title: "Ziyaretçiler",
                        detail: "Profiline son 7 günde bakanlar",
                        trailing: appState.profileVisits.isEmpty ? nil : "\(appState.profileVisits.count)") { showVisits = true }

                listDivider
                listRow(icon: "cup.and.saucer", title: "Buluşma istekleri",
                        detail: "Gelen ve gönderilen isteklerin",
                        badge: appState.pendingIncomingMeetingRequestCount) { showMeetingRequests = true }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))

            // Görünüm ayrı duruyor: satır değil, seçim.
            VStack(alignment: .leading, spacing: 10) {
                Text("GÖRÜNÜM")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(CampusTheme.muted)
                Picker("Görünüm", selection: $state.appearance) {
                    ForEach(AppState.Appearance.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, CampusTheme.Space.sm)


            VStack(spacing: 0) {
                listRow(icon: "rectangle.portrait.and.arrow.right", title: "Çıkış yap",
                        detail: "Bu cihazdaki oturumu kapat",
                        disabled: appState.isAccountActionInProgress) { showSignOutAlert = true }
                listDivider
                listRow(icon: "trash", title: "Hesabı kalıcı sil",
                        detail: "Geri alınamaz",
                        destructive: true,
                        disabled: appState.isAccountActionInProgress) { showDeleteAccountAlert = true }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
            .padding(.top, CampusTheme.Space.sm)

            // En altta: hukuki metinler ikincil, sık kullanılan işlemleri aşağı
            // itmemeli. Koşullar eskiden yalnızca karşılama ekranındaydı, yani
            // giriş yaptıktan sonra bir daha ulaşılamıyordu.
            VStack(spacing: 0) {
                listRow(icon: "doc.text", title: "Kullanım Koşulları",
                        detail: "Kuralların ve sorumlulukların") { showTerms = true }
                listDivider
                listRow(icon: "hand.raised", title: "Gizlilik Politikası",
                        detail: "Hangi bilgileri topluyoruz, ne yapıyoruz") { showPrivacy = true }
            }
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))

            if appState.isAccountActionInProgress {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Hesap işlemi tamamlanıyor…")
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
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(destructive ? CampusTheme.coral : CampusTheme.ink)
                    Text(detail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                Spacer(minLength: 0)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(CampusTheme.coral, in: Capsule())
                        .accessibilityLabel("\(badge) bekleyen")
                } else if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                        "Henüz ziyaretçi yok",
                        systemImage: "eye",
                        description: Text("Profilini görüntüleyenler burada görünecek. Son 7 gün gösterilir.")
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
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                            ProfileBadgeLabel(badge: visit.profile.badge, compact: true)
                                        }
                                        Text(visit.profile.department)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(CampusTheme.muted)
                                    }
                                    Spacer(minLength: 0)
                                    Text(visit.visitedAt.relativeTurkish)
                                        .font(.system(size: 11, design: .rounded))
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
            .navigationTitle("Ziyaretçiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { showVisits = false } }
            }
        }
    }

    private var savedPostsSheet: some View {
        NavigationStack {
            ScrollView {
                if appState.savedPosts.isEmpty {
                    ContentUnavailableView(
                        "Kaydedilen gönderi yok",
                        systemImage: "bookmark",
                        description: Text("Akışta bir gönderiyi yer imine eklediğinde burada görünecek.")
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
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Text(post.caption)
                                        .font(.system(size: 13, design: .rounded))
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
                                .accessibilityLabel("Kaydedilenlerden çıkar")
                            }
                            .padding(CampusTheme.Space.md)
                            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                        }
                    }
                    .padding(CampusTheme.Space.lg)
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Kaydedilenler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { showSaved = false } }
            }
        }
    }

    @ViewBuilder
    private var posts: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Gönderilerim")
            if appState.currentUserPosts.isEmpty {
                AppSurface {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(CampusTheme.violet)
                        Text("Henüz gönderin yok")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("İlk kampüs anını paylaştığında burada görünecek.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(CampusTheme.muted)
                            .multilineTextAlignment(.center)
                        // Paylaşım düğmesi profilin tepesindeki üçlü sıradan kaldırıldı
                        // (akış başlığındaki "Paylaş" ile birebir aynı işi yapıyordu).
                        // Boş durumda burada durması hem daha yerinde hem keşfedilebilir.
                        Button {
                            Haptics.impact(.light)
                            showComposer = true
                        } label: {
                            Text("BİR ŞEY PAYLAŞ")
                                .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                                .foregroundStyle(CampusTheme.paper)
                                .padding(.horizontal, 22).frame(height: 42)
                                .background(CampusTheme.ink, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
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

struct ProfileFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
