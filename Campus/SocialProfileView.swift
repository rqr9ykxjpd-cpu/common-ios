import SwiftUI

struct SocialProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSaved = false
    @State private var showVisits = false
    @State private var showComposer = false
    @State private var showMeetingRequests = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showEditor = false
    @State private var showCardPreview = false

    private var displayName: String { appState.draft.name.isEmpty ? "Cem" : appState.draft.name }
    private var department: String { appState.draft.department.isEmpty ? "Bölümünü ekle" : appState.draft.department }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    topBar
                    identity
                    completion
                    cardPreviewRow
                    metrics
                    about
                    meetingRequests
                    actions
                    posts
                    appearanceSection
                    accountActions
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
            .sheet(isPresented: $showSaved) { savedPostsSheet.task { await appState.loadSavedPosts() } }
            .sheet(isPresented: $showVisits) { visitorsSheet }
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

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Profil")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Common'da nasıl göründüğünü yönet")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
            Spacer()
            Button { showEditor = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(CampusTheme.surface, in: Circle())
                    .overlay(Circle().stroke(CampusTheme.hairline))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Profili düzenle")
        }
    }

    /// "Tanış'ta nasıl görünüyorum?" sorusunun cevabı. Profil alanlarını doldururken karşı
    /// tarafın gördüğü kartı görememek, neyin eksik kaldığını da görünmez kılıyordu.
    private var cardPreviewRow: some View {
        Button { showCardPreview = true } label: {
            HStack(spacing: CampusTheme.Space.md) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(width: 46, height: 46)
                    .background(CampusTheme.acid, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kartın nasıl görünüyor?")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Tanış'ta karşı tarafın gördüğü hali")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CampusTheme.ink.opacity(0.3))
            }
            .foregroundStyle(CampusTheme.ink)
            .padding(CampusTheme.Space.md)
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var identity: some View {
        HStack(spacing: CampusTheme.Space.lg) {
            ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(Circle().stroke(CampusTheme.surface, lineWidth: 3))
            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                Text("\(department) · \(appState.draft.year)")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                Label("Doğrulanmış YÜ öğrencisi", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CampusTheme.violet)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(CampusTheme.ink)
    }

    @ViewBuilder
    private var completion: some View {
        if appState.profileCompletion < 100 {
            AppSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Profilini tamamla")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Spacer()
                        Text("%\(appState.profileCompletion)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    ProgressView(value: Double(appState.profileCompletion), total: 100)
                        .tint(CampusTheme.violet)
                    Text("Daha iyi eşleşmeler için fotoğrafını, bio'nu ve ilgi alanlarını tamamla.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                    NavigationLink("Eksikleri tamamla") { ProfileEditorView() }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(CampusTheme.violet)
                }
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric(value: "\(appState.currentUserPosts.count)", label: "Gönderi")
            Rectangle()
                .fill(CampusTheme.hairline)
                .frame(width: 1, height: 34)
            metric(value: "\(appState.profileVisits.count)", label: "Ziyaretçi")
        }
        .padding(.vertical, CampusTheme.Space.sm)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CampusTheme.muted)
        }
        .foregroundStyle(CampusTheme.ink)
        .frame(maxWidth: .infinity)
    }

    private var about: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                Text("Hakkımda")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
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
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(CampusTheme.ink.opacity(0.055), in: Capsule())
                        }
                    }
                }
            }
            .font(.system(size: 14, design: .rounded))
            .lineSpacing(4)
        }
    }

    private var meetingRequests: some View {
        Button { showMeetingRequests = true } label: {
            HStack(spacing: CampusTheme.Space.md) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CampusTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(CampusTheme.acid, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buluşma İstekleri")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Gelen ve gönderilen isteklerini yönet")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
                Spacer()
                if appState.pendingIncomingMeetingRequestCount > 0 {
                    Text("\(appState.pendingIncomingMeetingRequestCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(CampusTheme.coral, in: Circle())
                        .accessibilityLabel("\(appState.pendingIncomingMeetingRequestCount) bekleyen istek")
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(CampusTheme.muted)
            }
            .foregroundStyle(CampusTheme.ink)
            .padding(CampusTheme.Space.lg)
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card).stroke(CampusTheme.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    private var actions: some View {
        HStack(spacing: CampusTheme.Space.sm) {
            AppButton(title: "Ziyaretçiler", systemName: "eye", role: .secondary) { showVisits = true }
            AppButton(title: "Kaydedilenler", systemName: "bookmark", role: .secondary) { showSaved = true }
            AppButton(title: "Gönderi", systemName: "plus", role: .accent) { showComposer = true }
        }
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
                        ForEach(appState.profileVisits) { visit in
                            HStack(spacing: CampusTheme.Space.md) {
                                ProfileMedia(url: visit.profile.imageURL, data: nil, assetName: nil)
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(visit.profile.name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Text(visit.profile.department)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(CampusTheme.muted)
                                }
                                Spacer(minLength: 0)
                                Text(visit.visitedAt.relativeTurkish)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(CampusTheme.muted)
                            }
                            .padding(CampusTheme.Space.md)
                            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
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

    /// Görünüm tercihi. Koyu mod zorunlu değil; isteyen buradan açıyor,
    /// varsayılan cihazın kendi ayarını izliyor.
    private var appearanceSection: some View {
        @Bindable var state = appState
        return VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Görünüm")
            AppSurface {
                VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                    Picker("Görünüm", selection: $state.appearance) {
                        ForEach(AppState.Appearance.allCases) { option in
                            Label(option.title, systemImage: option.icon).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(appState.appearance == .system
                         ? "Cihazının ayarını izler."
                         : "Uygulama her zaman \(appState.appearance.title.lowercased()) görünümde açılır.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                }
            }
        }
    }

    private var accountActions: some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            AppSectionHeader(title: "Hesap")
            AppSurface {
                VStack(spacing: 0) {
                    Button { showSignOutAlert = true } label: {
                        accountRow("Çıkış yap", detail: "Bu cihazdaki oturumu kapat", icon: "rectangle.portrait.and.arrow.right", destructive: false)
                    }
                    .disabled(appState.isAccountActionInProgress)
                    Divider().overlay(CampusTheme.hairline)
                    Button(role: .destructive) { showDeleteAccountAlert = true } label: {
                        accountRow("Hesabı kalıcı sil", detail: "Tüm hesap verilerini geri alınamaz biçimde sil", icon: "trash", destructive: true)
                    }
                    .disabled(appState.isAccountActionInProgress)
                }
            }
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

    private func accountRow(_ title: String, detail: String, icon: String, destructive: Bool) -> some View {
        HStack(spacing: CampusTheme.Space.md) {
            Image(systemName: icon)
                .frame(width: 36, height: 36)
                .background((destructive ? CampusTheme.coral : CampusTheme.ink).opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11, design: .rounded)).foregroundStyle(CampusTheme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(CampusTheme.muted)
        }
        .foregroundStyle(destructive ? CampusTheme.coral : CampusTheme.ink)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                    ForEach(appState.currentUserPosts) { post in
                        if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                            ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        } else {
                            Text(post.caption)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(CampusTheme.ink)
                                .lineLimit(5)
                                .padding(10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .aspectRatio(1, contentMode: .fit)
                                .background(CampusTheme.acid.opacity(0.35))
                        }
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
