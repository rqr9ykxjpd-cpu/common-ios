import SwiftUI
import AVFoundation

struct StoryViewer: View {
    @Environment(AppState.self) private var appState
    let stories: [CampusStory]
    let viewRecords: (UUID) -> [StoryViewRecord]
    let onViewed: (CampusStory) -> Void
    let onDelete: (UUID) -> Void
    /// Kendi story'nde çöpün yanındaki +: izleyiciyi kapatıp yeni story atar.
    var onAddStory: (() -> Void)? = nil
    let close: () -> Void
    @State private var currentIndex: Int
    /// Şu anki kare ne zaman oynamaya başladı; duraklatınca nil.
    @State private var playStartedAt: Date?
    /// Duraklatmadan önce oynanmış süre (saniye).
    @State private var playedBefore: TimeInterval = 0
    /// Geçiş yönü ve türü: kişi değişince kayar, aynı kişide çapraz solar.
    @State private var goingForward = true
    @State private var authorChanged = false
    @State private var heartBurst = 0
    @State private var holdTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var reportTarget: CampusStory?
    @State private var selectedStoryAuthor: StudentProfile?
    @FocusState private var replyFocused: Bool

    init(stories: [CampusStory], initialStoryID: UUID, viewRecords: @escaping (UUID) -> [StoryViewRecord], onViewed: @escaping (CampusStory) -> Void, onDelete: @escaping (UUID) -> Void, onAddStory: (() -> Void)? = nil, close: @escaping () -> Void) {
        self.stories = stories
        self.viewRecords = viewRecords
        self.onViewed = onViewed
        self.onDelete = onDelete
        self.onAddStory = onAddStory
        self.close = close
        _currentIndex = State(initialValue: stories.firstIndex(where: { $0.id == initialStoryID }) ?? 0)
    }

    private var story: CampusStory? {
        stories.indices.contains(currentIndex) ? stories[currentIndex] : nil
    }

    private var isInteractionBlocking: Bool {
        replyFocused || selectedStoryAuthor != nil || isPaused || showDeleteConfirmation || showViewers || reportTarget != nil
    }

    var body: some View {
        VStack(spacing: 10) {
            if let story {
                // Kart: medya ve üstündeki bilgi. Kişi değişince kart kayar,
                // aynı kişinin sıradaki karesinde çapraz solar.
                ZStack {
                    storyCard(story)
                        .id(story.id)
                        .transition(cardTransition)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .scaleEffect(isPaused ? 0.985 : 1)
                .padding(.horizontal, 4)

                storyFooter(story)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            } else {
                Spacer()
                Button(L10n.Common.close, action: close).foregroundStyle(.white)
                Spacer()
            }
        }
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
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
        .task(id: "\(currentIndex)-\(replyFocused)-\(selectedStoryAuthor != nil)-\(isPaused)-\(showDeleteConfirmation)-\(showViewers)-\(reportTarget != nil)") {
            await playCurrentStory()
        }
        // Basılı tutunca duraklatma Plus'a özel. Ücretsizde basılı tutmak, bunun
        // bir özellik olduğunu gösteren ipucunu açıyor.
        //
        // `onPressingChanged` parmak değer değmez `true` geliyor; eskiden her
        // dokunuşta (kalp, ileri) ipucu çıkıyor, Plus'ta ekran bir an duruyordu.
        // Artık yalnızca gerçekten basılı tutulunca (0,22 sn) devreye giriyor.
        .onLongPressGesture(minimumDuration: 0.22, maximumDistance: 24) { } onPressingChanged: { basiliyor in
            holdTask?.cancel()
            if basiliyor {
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    if appState.tier.canPauseStory {
                        withAnimation(.easeOut(duration: 0.15)) { isPaused = true }
                    } else {
                        // Hareketin ortasında modal açmak kullanıcıyı hapsediyordu;
                        // story akmaya devam ediyor, engellemeyen bir ipucu beliriyor.
                        withAnimation(.easeOut(duration: 0.15)) { pauseHintVisible = true }
                        Haptics.impact(.light)
                    }
                }
            } else if isPaused {
                withAnimation(.easeOut(duration: 0.15)) { isPaused = false }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog(L10n.Common.report, isPresented: Binding(
            get: { reportTarget != nil },
            set: { if !$0 { reportTarget = nil } }
        ), titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.title) {
                    if let reportTarget {
                        appState.reportContent(.init(kind: .story, id: reportTarget.id), reason: reason)
                    }
                    reportTarget = nil
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { reportTarget = nil }
        }
        .task(id: pauseHintVisible) {
            guard pauseHintVisible else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.2)) { pauseHintVisible = false }
        }
        .sheet(item: $selectedStoryAuthor) { profile in
            NavigationStack {
                ProfilePhotoStackView(profile: profile)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
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

    private var cardTransition: AnyTransition {
        if reduceMotion || !authorChanged { return .opacity }
        return .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }

    private func storyCard(_ story: CampusStory) -> some View {
        GeometryReader { proxy in
            ZStack {
                StoryMediaCanvas(
                    url: story.imageURL, data: story.localImageData, assetName: story.imageAssetName,
                    videoURL: story.isVideo ? story.videoURL : nil, isPaused: isInteractionBlocking
                )
                .frame(width: proxy.size.width, height: proxy.size.height)

                // Yazı okunsun diye yalnızca üst ve alt kenarda karartma; ortası temiz.
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 190)
                }
                .allowsHitTesting(false)

                // Instagram'daki gibi: sol üçte bir geri, kalanı ileri.
                HStack(spacing: 0) {
                    Button(action: previous) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .frame(width: proxy.size.width * 0.35)
                        .accessibilityLabel(L10n.Story.previous)
                    Button(action: next) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Story.next)
                }
                .padding(.top, 70)

                VStack(alignment: .leading, spacing: 10) {
                    progressBars
                    storyHeader(story)
                    Spacer(minLength: 0)
                    storyCaption(story)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 16)
                // Basılı tutunca arayüz çekilir, yalnızca fotoğraf kalır.
                .opacity(isPaused ? 0 : 1)
                .zIndex(2)

                heartBurstView
            }
        }
    }

    /// Beğenince kartın ortasında büyüyüp sönen kalp.
    private var heartBurstView: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 96, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 14, y: 4)
            .keyframeAnimator(initialValue: HeartBurst(), trigger: heartBurst) { content, value in
                content.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.15, duration: 0.28, spring: .bouncy)
                    CubicKeyframe(1.0, duration: 0.12)
                    CubicKeyframe(1.25, duration: 0.25)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.06)
                    LinearKeyframe(1, duration: 0.4)
                    LinearKeyframe(0, duration: 0.2)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct HeartBurst {
        var scale: CGFloat = 0.5
        var opacity: Double = 0
    }

    /// "12 dk", "3 sa": story'nin ne kadar taze olduğu, başlıkta ismin yanında.
    private func ageText(_ story: CampusStory) -> String {
        let olusma = story.expiresAt.addingTimeInterval(-CampusStory.lifetime)
        let dakika = max(0, Int(Date.now.timeIntervalSince(olusma) / 60))
        if dakika < 60 { return L10n.Story.ageMinutes(max(1, dakika)) }
        return L10n.Story.ageHours(dakika / 60)
    }

    /// Eskiden ilerleme 50 ms'de bir durum değiştirip bütün ekranı (medya dahil)
    /// saniyede 20 kez yeniden çiziyordu; çubuk da kesik kesik ilerliyordu.
    /// Şimdi yalnızca çubuklar, ekranın kendi hızında, zamandan hesaplanıyor.
    private var progressBars: some View {
        TimelineView(.animation(paused: playStartedAt == nil)) { context in
            let simdi = currentProgress(at: context.date)
            HStack(spacing: 3) {
                ForEach(stories.indices, id: \.self) { index in
                    let dolu: CGFloat = index < currentIndex ? 1 : (index == currentIndex ? simdi : 0)
                    Capsule().fill(.white.opacity(0.32))
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule().fill(.white).frame(width: geo.size.width * dolu)
                            }
                        }
                        .frame(height: 2.5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Story.progress(currentIndex + 1, stories.count))
    }

    private func currentProgress(at date: Date) -> CGFloat {
        guard let story else { return 0 }
        var gecen = playedBefore
        if let playStartedAt { gecen += date.timeIntervalSince(playStartedAt) }
        return min(1, CGFloat(gecen / playbackDuration(for: story)))
    }

    private func storyHeader(_ story: CampusStory) -> some View {
        HStack(spacing: 11) {
            Button { selectedStoryAuthor = story.author } label: {
                HStack(spacing: 11) {
                    ProfileMedia(url: story.author.imageURL, data: nil, assetName: story.author.imageAssetName)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            // İsim asla kesilmesin: rozet yalnızca işaret, tazelik en sonda.
                            Text(story.author.name)
                                .font(.system(size: 15, weight: .bold))
                                .lineLimit(1)
                                .fixedSize()
                            if let icon = story.author.badge.systemImage {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(story.author.badge == .founder ? BondTheme.ember : .white.opacity(0.92))
                                    .accessibilityLabel(story.author.badge.title ?? "")
                            }
                            Text(ageText(story))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        if let place = story.place {
                            // Tek satır: kendi story'nde sağda dört düğme var, yer
                            // adı iki satıra kelimenin ortasından bölünüyordu.
                            HStack(spacing: 3) {
                                Image(systemName: "mappin").font(.system(size: 10, weight: .semibold))
                                Text(place.name).lineLimit(1).truncationMode(.tail)
                            }
                            .font(.system(size: 12))
                            .opacity(0.72)
                        }
                    }
                }
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Feed.openProfile(story.author.name))
            Spacer(minLength: 4)
            // Sağdaki düğmeler kendi aralarında boşluksuz: her biri zaten 44pt
            // dokunma alanında. Aradaki 11'er puanlık boşluk kendi story'nde yer
            // adını "Şamd…" diye kesiyordu.
            HStack(spacing: 0) {
            if !story.isMine {
                Button { reportTarget = story } label: {
                    Image(systemName: "flag").frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Common.report)
            }
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
                        .padding(.horizontal, 11)
                        .frame(height: 44)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                .accessibilityLabel("\(L10n.Story.viewersTitle), \(appState.stories.first(where: { $0.id == story.id })?.viewRecords.count ?? viewRecords(story.id).count)")
            }
            if story.isMine, let onAddStory {
                Button(action: onAddStory) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Composer.shareStory)
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
            // Düğmeler ve izleyen sayısı hiç sıkışmaz; yer darsa kısalan yer adı olur.
            .fixedSize()
        }
    }

    /// Kartın altındaki yazı ve (ücretsizde) duraklatma ipucu.
    private func storyCaption(_ story: CampusStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Ücretsiz kullanıcı basılı tuttuğunda: story durmuyor, akış
            // kesilmiyor; yalnızca özelliğin var olduğunu söyleyen bir ipucu.
            // Dokunursa Plus ekranı açılıyor — ama zorlamıyor.
            if pauseHintVisible {
                Button { showPaywall = true } label: {
                    Label(L10n.Story.pausePlus, systemImage: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BondTheme.canvasDark)
                        .padding(.horizontal, 11).frame(height: 28)
                        .background(BondTheme.onCanvasDark, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .transition(.opacity)
            }
            if !story.caption.isEmpty {
                Text(story.caption)
                    .font(.system(size: 22, weight: .semibold))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Kartın altında, siyah zeminde yanıt şeridi.
    private func storyFooter(_ story: CampusStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                                .font(.system(size: 22)).foregroundStyle(liked ? BondTheme.coral : .white)
                                .symbolEffect(.bounce, options: .nonRepeating, value: liked)
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(liked ? L10n.Story.unlike : L10n.Story.like)
                        TextField("", text: $reply, prompt: Text(L10n.Story.replyPlaceholder).foregroundStyle(.white.opacity(0.5)))
                            .focused($replyFocused)
                            .padding(.horizontal, 16).frame(height: 46)
                            .background(.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.28)))
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
                    TextField("", text: $reply, prompt: Text(L10n.Story.replyTo(story.author.name)).foregroundStyle(.white.opacity(0.5)))
                        .focused($replyFocused)
                        .padding(.horizontal, 16).frame(height: 46)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.28)))
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
        guard let story, !isInteractionBlocking else {
            freezeProgress()
            return
        }
        let kalan = playbackDuration(for: story) - playedBefore
        guard kalan > 0 else { next(); return }
        playStartedAt = .now
        do {
            try await Task.sleep(for: .seconds(kalan))
        } catch {
            // Duraklatma (ya da sayfa) iptali: o ana kadar oynanan süreyi sakla.
            freezeProgress()
            return
        }
        guard !Task.isCancelled else { return }
        next()
    }

    private func freezeProgress() {
        guard let playStartedAt else { return }
        playedBefore += Date.now.timeIntervalSince(playStartedAt)
        self.playStartedAt = nil
    }

    private func playbackDuration(for story: CampusStory) -> TimeInterval {
#if DEBUG
        if appState.debugSlowStories { return 60 }
#endif
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
        playStartedAt = nil
        playedBefore = 0
        reply = ""
        replySent = false
        liked = false
        replyFocused = false
    }

    private func previous() {
        prepareForTransition()
        guard currentIndex > 0 else { return }
        move(to: currentIndex - 1, forward: false)
    }

    private func next() {
        prepareForTransition()
        guard currentIndex < stories.count - 1 else { close(); return }
        move(to: currentIndex + 1, forward: true)
    }

    private func move(to index: Int, forward: Bool) {
        goingForward = forward
        authorChanged = stories[index].author.id != stories[currentIndex].author.id
        withAnimation(reduceMotion ? nil : .smooth(duration: authorChanged ? 0.36 : 0.22)) {
            currentIndex = index
        }
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
        if yeni {
            heartBurst += 1
            Haptics.impact(.light)
        }
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
