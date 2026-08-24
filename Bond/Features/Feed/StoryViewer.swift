import SwiftUI
import AVFoundation

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
    @State private var pendingDeleteID: UUID?
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

    private var isInteractionBlocking: Bool {
        replyFocused || selectedStoryAuthor != nil || isPaused || showDeleteConfirmation || showViewers
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let story {
                    storyCanvas(story, size: proxy.size)
                    LinearGradient(colors: [.black.opacity(0.64), .clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        Button(action: previous) {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Story.previous)
                        Button(action: next) {
                            Color.clear.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Story.next)
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
                    // Önceki/sonraki dokunma katmanının üstünde kalsın; sil düğmesi
                    // altındaki şeffaf butona yemesin.
                    .zIndex(2)
                } else {
                    Button(L10n.Common.close, action: close).foregroundStyle(.white)
                }
            }
        }
        .onAppear { activatePlaybackAudio() }
        .onDisappear { deactivatePlaybackAudio() }
        .task(id: currentIndex) {
            if let story {
                onViewed(story)
                liked = await appState.isStoryLiked(story.id)
            }
        }
        // Onay diyaloğu açıkken de duraklat: aksi halde altta story ilerleyip
        // silinecek kimlik kayboluyordu.
        .task(id: "\(currentIndex)-\(replyFocused)-\(selectedStoryAuthor != nil)-\(isPaused)-\(showDeleteConfirmation)-\(showViewers)") {
            await playCurrentStory()
        }
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
                SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
            }
        }
        .sheet(isPresented: $showViewers) {
            if let story {
                StoryViewersSheet(story: story, records: viewRecords(story.id))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                // Story araya silinmiş olabilir; boş bir sayfa açmak yerine sebebini söylüyoruz.
                ContentUnavailableView(
                    L10n.Story.missing,
                    systemImage: "eye.slash"
                )
                    .presentationDetents([.medium])
            }
        }
        .alert(
            (story?.isMine == true) ? L10n.Story.deleteConfirm : L10n.Moderation.removeStory,
            isPresented: $showDeleteConfirmation
        ) {
            Button(
                (story?.isMine == true) ? L10n.Story.delete : L10n.Moderation.removeStory,
                role: .destructive
            ) {
                let id = pendingDeleteID ?? story?.id
                pendingDeleteID = nil
                guard let id else { return }
                onDelete(id)
                close()
            }
            Button(L10n.Common.cancel, role: .cancel) {
                pendingDeleteID = nil
            }
        } message: {
            Text(L10n.Feed.irreversible)
        }
    }

    @ViewBuilder
    private func storyCanvas(_ story: CampusStory, size: CGSize) -> some View {
        Group {
            if story.isVideo, let url = story.videoURL {
                StoryVideoCanvas(url: url, isPaused: isInteractionBlocking)
            } else {
                ProfileMedia(url: story.imageURL, data: story.localImageData, assetName: story.imageAssetName)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Story.progress(currentIndex + 1, stories.count))
    }

    private func storyHeader(_ story: CampusStory) -> some View {
        HStack(spacing: 11) {
            Button { selectedStoryAuthor = story.author } label: {
                HStack(spacing: 11) {
                    ProfileMedia(url: story.author.imageURL, data: nil, assetName: story.author.imageAssetName)
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(story.author.name).font(.system(size: 15, weight: .bold))
                            // Post kartındaki gibi kurucu / doğrulanmış rozeti.
                            if let icon = story.author.badge.systemImage,
                               let title = story.author.badge.title {
                                Label(title, systemImage: icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(
                                        story.author.badge == .founder
                                            ? BondTheme.ember
                                            : .white.opacity(0.92)
                                    )
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        if let place = story.place {
                            Label(place.name, systemImage: "mappin").font(.system(size: 12)).opacity(0.72)
                        }
                    }
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Feed.openProfile(story.author.name))
            Spacer()
            if story.isMine {
                Button { showViewers = true } label: {
                    // Göz işareti kaç *kişi* izlediğini gösteriyor: aynı kişinin tekrar
                    // izlemesi sayıyı artırmaz. Kaç kez izlendiği izleyici listesinde,
                    // kişi bazında ("3 kez") ve "Toplam izleme" özetinde duruyor.
                    // Canlı AppState listesi: açılıştaki boş snapshot 0'da kilitlenmesin.
                    let count = appState.stories.first(where: { $0.id == story.id })?.viewRecords.count
                        ?? viewRecords(story.id).count
                    Label("\(count)", systemImage: "eye.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                .accessibilityLabel("\(L10n.Story.viewersTitle), \(appState.stories.first(where: { $0.id == story.id })?.viewRecords.count ?? viewRecords(story.id).count)")
            }
            // Menü + confirmationDialog fullScreenCover içinde çoğu zaman
            // açılmıyordu. Tek eylem için doğrudan çöp + alert daha güvenilir.
            // Kurucu/moderatör başkasının story'sini de kaldırabilir.
            if story.isMine || appState.isModerator {
                Button {
                    pendingDeleteID = story.id
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(
                    story.isMine ? L10n.Story.delete : L10n.Moderation.removeStory
                )
            }
            Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel(L10n.Common.close)
        }
    }

    private func storyFooter(_ story: CampusStory) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if isPaused {
                Label(L10n.Story.paused, systemImage: "pause.fill")
                    .font(.system(size: 11, weight: .bold))
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
                    Label(L10n.Story.pausePro, systemImage: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BondTheme.canvasDark)
                        .padding(.horizontal, 11).frame(height: 28)
                        .background(BondTheme.onCanvasDark, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .transition(.opacity)
            }
            Text(story.caption).font(.system(size: 24, weight: .semibold))
            if story.isMine {
                // Kendi story'ne yanıt yazma alanı çıkıyordu.
                EmptyView()
            } else if replySent {
                Label(conversation(with: story.author) == nil ? "İsteğin gönderildi" : "Yanıt gönderildi",
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(BondTheme.onCanvasDark)
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
                                .font(.system(size: 20)).foregroundStyle(liked ? BondTheme.coral : .white)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(liked ? L10n.Story.unlike : L10n.Story.like)
                        TextField(L10n.Story.replyPlaceholder, text: $reply)
                            .focused($replyFocused)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(.black.opacity(0.2), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.55)))
                        Button { sendRequest() } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20)).foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .opacity(reply.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
                        }
                        .disabled(reply.trimmingCharacters(in: .whitespaces).isEmpty || sendingRequest)
                        .accessibilityLabel(L10n.Story.sendRequest)
                    }
                    // Ne olacağını önden söylüyoruz: kullanıcı mesajının
                    // doğrudan gittiğini sanıp cevap beklemesin.
                    Text(L10n.Story.requestHint)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.leading, 4)
                }
            } else {
                HStack(spacing: 10) {
                    TextField(L10n.Story.replyTo(story.author.name), text: $reply)
                        .focused($replyFocused)
                        .padding(.horizontal, 16).frame(height: 46)
                        .background(.black.opacity(0.2), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.55)))
                    Button { sendReply() } label: {
                        Image(systemName: reply.isEmpty ? "heart.fill" : "paperplane.fill")
                            .font(.system(size: 20)).foregroundStyle(liked ? BondTheme.coral : .white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(reply.isEmpty ? L10n.Chat.sendHeart : L10n.Common.send)
                }
            }
        }
    }

    @MainActor
    private func playCurrentStory() async {
        guard let story, !isInteractionBlocking else { return }

        let tick = Duration.milliseconds(50)
        let duration = playbackDuration(for: story)
        let steps = max(1, duration / 0.05)
        let increment: CGFloat = 1 / CGFloat(steps)
        while progress < 1 {
            do {
                try await Task.sleep(for: tick)
            } catch {
                return
            }
            guard !Task.isCancelled, !isInteractionBlocking else { return }
            progress = min(1, progress + increment)
        }
        guard !Task.isCancelled else { return }
        next()
    }

    private func playbackDuration(for story: CampusStory) -> TimeInterval {
        if story.isVideo {
            return min(CampusStory.maxVideoDuration, max(0.5, story.duration ?? CampusStory.maxVideoDuration))
        }
        return CampusStory.photoPlayback
    }

    private func activatePlaybackAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivatePlaybackAudio() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

struct StoryViewersSheet: View {
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
                    HStack(spacing: BondTheme.Space.lg) {
                        summary(value: "\(records.count)", label: L10n.Story.people)
                        if appState.tier.canSeeStoryViewCounts {
                            summary(value: "\(totalViews)", label: L10n.Story.totalViews)
                        } else {
                            Button { showProNote = true } label: {
                                summary(value: "↑", label: L10n.Story.totalViews)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.bottom, BondTheme.Space.lg)

                    if records.isEmpty {
                        ContentUnavailableView(
                            L10n.Story.noViewers,
                            systemImage: "eye.slash",
                            description: Text(L10n.Story.noViewersBody)
                        )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BondTheme.Space.xxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(records.sorted(by: { $0.lastViewedAt > $1.lastViewedAt })) { record in
                                NavigationLink {
                                    SocialPersonDetailView(profile: record.viewer, place: nil)
                                } label: {
                                    HStack(spacing: BondTheme.Space.md) {
                                        ProfileMedia(url: record.viewer.imageURL, data: nil, assetName: record.viewer.imageAssetName)
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.viewer.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(record.lastViewedAt.relativeTurkish)
                                                .font(.system(size: 11))
                                                .foregroundStyle(BondTheme.muted)
                                        }
                                        Spacer()
                                        // Kaç kez izlendiği Pro'ya özel. Kendi
                                        // izlemelerini herkes görebiliyor.
                                        if appState.tier.canSeeStoryViewCounts
                                            || record.viewer.id == appState.currentUserID {
                                            Text(L10n.Story.viewCount(record.viewCount))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(BondTheme.violet)
                                                .padding(.horizontal, 10)
                                                .frame(height: 30)
                                                .background(BondTheme.violet.opacity(0.1), in: Capsule())
                                        } else {
                                            Button { showProNote = true } label: {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(BondTheme.violet)
                                                    .frame(width: 30, height: 30)
                                                    .background(BondTheme.violet.opacity(0.1), in: Circle())
                                            }
                                            .buttonStyle(PressableStyle())
                                            .accessibilityLabel(L10n.Story.viewCountLocked)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(BondTheme.muted)
                                    }
                                    .foregroundStyle(BondTheme.ink)
                                    .contentShape(Rectangle())
                                    .padding(.vertical, BondTheme.Space.md)
                                    .overlay(alignment: .bottom) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel(L10n.Feed.openProfile(record.viewer.name))
                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Story.viewersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .sheet(isPresented: $showProNote) {
                ProUpsellSheet().presentationDetents([.height(320)])
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 22, weight: .bold))
            Text(label).font(.system(size: 12)).foregroundStyle(BondTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BondTheme.Space.lg)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface))
        .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.surface).stroke(BondTheme.hairline))
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
