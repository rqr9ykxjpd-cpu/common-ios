import SwiftUI
import UIKit

struct SocialPersonDetailView: View {
    let profile: StudentProfile
    let place: CampusPlace?
    /// Sheet'in kökü olarak açıldığında `true`. İtilerek açıldığında sistem
    /// kendi geri düğmesini koyuyor; buna ek olarak bir tane daha eklemek
    /// yan yana iki geri düğmesi bırakıyordu.
    var showsClose = false
    /// "Kartını düzenle"deki canlı önizleme: kaydedilmemiş rengi göstermek için.
    var themeOverride: CardTheme? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.dismiss) private var dismiss
    @State private var conversationRoute: ConversationRoute?
    @State private var isOpeningFounderChat = false
    @State private var details: PersonProfileData?
    @State private var detailsError: String?
    @State private var isLoadingDetails = false
    @State private var isSendingSwipe = false
    @State private var showBlockConfirmation = false
    @State private var showSuspendConfirmation = false

    // Kart kaydırma. Sağ = bağlantı isteği, sol = kapat. Fotoğraf destesi
    // yatay pan almıyor; bu jest kartın tamamına ait.
    @State private var cardOffset: CGFloat = 0
    @State private var kartKoken: CGPoint = .zero
    /// İlk açılışlardaki kıpırdama sürerken `true`.
    @State private var cardPeeking = false
    @AppStorage("kartKaydirmaIpucu") private var swipePeekCount = 0
    @State private var cardDragging = false
    @State private var cardFlying = false
    @State private var showsUndo = false
    @State private var undoTask: Task<Void, Never>?
    /// Sağa kaydırma sonrası ortada beliren onay.
    @State private var showSentBurst = false
    @State private var showConnectedMoment = false
    @State private var avatarsTogether = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Kart elde: altındaki masa görünür.
    private var cardLifted: Bool { cardDragging || cardFlying }
    /// Köşeler yuvarlanıp gölge düşüyor. Kıpırdamada masa değişmiyor: bir
    /// ipucu için zeminin bir anlığına koyulaşması fazla sertti.
    private var cardDetached: Bool { cardLifted || cardPeeking }
    /// Alt şeridin içeriği var mı. Bağlı olmayan birinde boş kalıyordu ve
    /// zemini kart kalkınca altta küçük bir kare olarak görünüyordu.
    private var hasBottomBar: Bool { !isMe && (isMatched || kurucu || showsUndo) }
    /// Zemin, kart ve alt şeridin çizgilerini hizalayan ortak düzlem.
    private static let sayfaDuzlemi = "kartSayfasi"
    /// Çizgili şeridin kartın üst kenarından aşağı uzunluğu.
    private static let seritBoyu: CGFloat = 150
    /// Kartın rengi: önizleme > (kendi kartımsa) taslaktaki > hızlı okunan >
    /// ayrıntılarla gelen. Kendi kartında taslak önde: az önce kaydettiğin renk
    /// sunucudan dönmesini beklemeden görünsün.
    private var theme: CardTheme {
        if let themeOverride { return themeOverride }
        if isMe { return appState.draft.cardTheme }
        return appState.cardThemes[profile.id] ?? details?.cardTheme ?? .classic
    }
    /// Kart kendi şemasını alıyor; kartın açtığı sayfalar (sohbet vb.) almıyor,
    /// çünkü sheet'ler bu değiştiricinin dışında bağlı.
    private var cardScheme: ColorScheme { theme.scheme ?? systemScheme }
    /// 100pt eşiğe göre 0…1. Etiket opaklığı ve gölge buradan.
    private var swipeProgress: CGFloat { min(abs(cardOffset) / 100, 1) }
    private var swipingRight: Bool { cardOffset > 0 }

    private var isMe: Bool { profile.id == appState.currentUserID }
    private var alreadySwiped: Bool { appState.rightSwipedProfileIDs.contains(profile.id) }
    private var isMatched: Bool { conversation(with: profile) != nil }
    /// Eşleşme isteği: fotoğraf destesinden ayrı (buton). Kaydırma fotoğrafta yalnızca fotoğraf.
    private var allowsMatchRequest: Bool { !isMe && !isMatched && !alreadySwiped }

    private func conversation(with person: StudentProfile) -> Conversation? {
        appState.conversations.first(where: { $0.profile.id == person.id })
    }

    private var visiblePlace: CampusPlace? { place }

    private var kurucu: Bool { (details?.badge ?? profile.badge) == .founder }

    private func cipZemini(paylasilan: Bool) -> Color {
        // Renkli kartta turuncu zemin kartın rengine karışıyor (kiremitte hiç
        // görünmüyordu); ortak ilgi orada daha koyu bir mürekkep tonu.
        if theme != .classic { return BondTheme.ink.opacity(paylasilan ? 0.16 : 0.07) }
        if paylasilan { return BondTheme.burntOrange.opacity(0.14) }
        return kurucu ? BondTheme.ember.opacity(0.12) : BondTheme.ink.opacity(0.055)
    }

    private var pendingRequest: MeetingRequest? {
        guard let visiblePlace else { return nil }
        return appState.meetingRequest(for: profile, at: visiblePlace)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Kart kalkınca altındaki masa görünür.
            Group {
                if cardLifted {
                    BondTheme.surface
                } else {
                    AlignedCardThemeSurface(theme: theme, space: Self.sayfaDuzlemi, fadeOut: Self.seritBoyu)
                }
            }
                .ignoresSafeArea()
                .animation(BondTheme.Motion.smooth, value: cardLifted)

            // Renk geçişi animasyonsuz: yazının rengi (şema) anında dönüyor,
            // zemin yavaş dönerse bir an beyaz üstüne beyaz yazı kalıyordu.
            cardBody
                .overlay(alignment: .topLeading) { swipeStamp(right: false) }
                .overlay(alignment: .topTrailing) { swipeStamp(right: true) }
                // Çizgiler kartın başında bir şerit olarak kalıyor ve yazıya
                // varmadan sönüyor: tam kartta küçük yazılar desenin içinde
                // kayboluyordu.
                .background(CardThemeSurface(theme: theme, origin: kartKoken, fadeOut: Self.seritBoyu))
                // Kartın durduğu yer; çizgiler zeminle ve alt şeritle aynı
                // ızgarada. Kaydırılırken ölçülmüyor: çizgiler kartla gitsin.
                .onGeometryChange(for: CGPoint.self) {
                    $0.frame(in: .named(Self.sayfaDuzlemi)).origin
                } action: { yeni in
                    if cardOffset == 0 { kartKoken = yeni }
                }
                .clipShape(RoundedRectangle(cornerRadius: cardDetached ? 28 : 0, style: .continuous))
                // Kıpırdamada masa kartla aynı renk; kartı ayıran gölge.
                .shadow(color: .black.opacity(0.18 * max(swipeProgress, cardPeeking ? 0.7 : 0)), radius: 24, y: 12)
                .offset(x: cardOffset)
                // Tinder'daki gibi: kart yatay çekildikçe alt köşesinden döner.
                .rotationEffect(.degrees(max(-12, min(12, cardOffset / 14))), anchor: .bottom)
                .scaleEffect(1 - 0.03 * swipeProgress)
                .simultaneousGesture(cardSwipeGesture)

            if showSentBurst {
                sentBurst
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            if showConnectedMoment {
                connectedMoment
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, cardScheme)
        .safeAreaInset(edge: .bottom) {
            if hasBottomBar {
                VStack(spacing: 8) {
                    // Yanlışlıkla sağa kaydırmak kolay; istek gittikten sonra kısa
                    // süre geri alınabilsin. Bilgi şeridi kart sayfasının arkasında
                    // kaldığı için düğme kartın kendi alt şeridinde duruyor.
                    if showsUndo {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BondTheme.acid)
                            Text(L10n.CampusDesign.rightSwipeSent)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(BondTheme.ink)
                            Spacer(minLength: 0)
                            Button { Task { await undoConnect() } } label: {
                                Text(L10n.Common.undo)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(BondTheme.burntOrangeText)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                            }
                            .buttonStyle(PressableStyle())
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(BondTheme.surface, in: Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    actions
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.background)
                .environment(\.colorScheme, cardScheme)
            }
        }
        .coordinateSpace(.named(Self.sayfaDuzlemi))
        .confirmationDialog(L10n.Moderation.suspendAccount, isPresented: $showSuspendConfirmation, titleVisibility: .visible) {
            Button(L10n.Moderation.suspendAccount, role: .destructive) {
                Task {
                    await appState.suspendAccount(profile.id)
                    dismiss()
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Moderation.suspendAccountBody)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Araç çubuğu sayfanın ortamını almıyor; koyu kartta yazı
                // koyu kalıp kayboluyordu.
                Wordmark(compact: true)
                    .environment(\.colorScheme, cardScheme)
            }
            if showsClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { cardBarGlyph("xmark") }
                        .accessibilityLabel(L10n.Common.close)
                }
                .withoutSharedGlass()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu {
                        ForEach(ReportReason.allCases) { reason in
                            Button(reason.title) { appState.report(profile, reason: reason) }
                        }
                    } label: {
                        Label(L10n.Common.report, systemImage: "flag")
                    }
                    Button(L10n.Feed.blockUser, role: .destructive) {
                        showBlockConfirmation = true
                    }
                    if appState.isModerator, !isMe,
                       profile.badge != .founder, profile.badge != .moderator {
                        Divider()
                        Button(L10n.Moderation.suspendAccount, systemImage: "nosign", role: .destructive) {
                            showSuspendConfirmation = true
                        }
                    }
                } label: {
                    cardBarGlyph("ellipsis")
                }
            }
            .withoutSharedGlass()
        }
        .confirmationDialog(
            L10n.Chat.blockConfirm(profile.name),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Feed.blockUser, role: .destructive) {
                appState.block(profile)
                dismiss()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Chat.blockBody)
        }
        .task(id: profile.id) {
            appState.recordProfileVisit(profile)
            // Renk ayrı ve önce: ayrıntılar fotoğrafları imzalamadan dönmüyor.
            async let renk: Void = appState.loadCardTheme(for: profile.id)
            await reloadDetails()
            await renk
        }
        .task(id: profile.id) { await peekSwipeIfNeeded() }
        .fullScreenCover(item: $conversationRoute) { route in
            NavigationStack { ConversationView(conversationID: route.id, showsClose: true) }
        }
    }

    @ViewBuilder private var interestList: some View {
        let hepsi = details?.interests ?? profile.interests
        if !hepsi.isEmpty {
            let benimkiler = isMe ? [] : appState.draft.interests
            let ortak = hepsi.filter { benimkiler.contains($0) }
            VStack(alignment: .leading, spacing: 8) {
                if !ortak.isEmpty {
                    Text(L10n.Profile.sharedInterests(ortak.count))
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.7)
                        .foregroundStyle(theme == .classic ? BondTheme.burntOrangeText : BondTheme.ink)
                }
                FlowLayout(spacing: 7) {
                    ForEach(hepsi, id: \.self) { interest in
                        let paylasilan = benimkiler.contains(interest)
                        Text(InterestCatalog.displayName(interest))
                            .font(.footnote.weight(paylasilan ? .bold : .medium))
                            .foregroundStyle(BondTheme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(cipZemini(paylasilan: paylasilan), in: Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder private var gallery: some View {
        if isLoadingDetails && galleryPhotos.isEmpty {
            ProgressView(L10n.ScreenStates.photoLoading).frame(maxWidth: .infinity, minHeight: 44)
        } else if !galleryPhotos.isEmpty {
            // Fotoğrafı sürüklemek fotoğrafı çevirir. Kartın bağlan/kapat jesti
            // fotoğrafın dışında: isim bloğu ve alt bilgiler.
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                profileSectionTitle(L10n.Profile.photos)
                ProfileGalleryStack(photos: galleryPhotos)
            }
        }
    }

    private var galleryPhotos: [ProfileGalleryPhoto] {
        let extras = ProfileGalleryPhoto.remote(
            (details?.galleryURLs ?? profile.galleryImageURLs).filter { url in
                guard let avatar = details?.avatarURL ?? profile.imageURL else { return true }
                return url.path != avatar.path
            }
        )
        var deck = ProfileGalleryPhoto.deck(gallery: extras)
        if deck.isEmpty {
            if let avatar = details?.avatarURL ?? profile.imageURL {
                deck = [ProfileGalleryPhoto(id: "avatar:\(avatar.absoluteString)", url: avatar)]
            } else if let asset = profile.imageAssetName {
                deck = [ProfileGalleryPhoto(id: "avatar-asset:\(asset)", assetName: asset)]
            }
        }
        return deck
    }

    @MainActor
    private func sendRightSwipe() async {
        guard allowsMatchRequest, !isSendingSwipe else { return }
        isSendingSwipe = true
        defer { isSendingSwipe = false }
        switch await appState.sendRightSwipe(to: profile) {
        case .matched(let matchID):
            // İki taraf da istek göndermiş → önce an, sonra sohbet.
            await presentConnectedMoment(then: matchID)
        case .sent:
            // Kart açık kalır; alt yazı "İstek gönderildi" olur, altında geri alma.
            withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { showsUndo = true }
            undoTask?.cancel()
            undoTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { showsUndo = false }
            }
        case .already:
            break
        case .failed:
            break
        }
    }

    /// İstek gönderildikten sonra kısa süre görünen "Geri al" düğmesi.
    private func undoConnect() async {
        undoTask?.cancel()
        await appState.undoRightSwipe(on: profile)
        withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { showsUndo = false }
    }

    // MARK: - Kart kaydırma

    /// Kart jesti: fotoğrafın dışındaki her yer (isim bloğu, alt bilgiler).
    private var cardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                cardDragChanged(x: value.translation.width, y: value.translation.height)
            }
            .onEnded { value in
                cardDragEnded(x: value.translation.width, y: value.translation.height,
                              predictedX: value.predictedEndTranslation.width)
            }
    }

    private func cardDragChanged(x: CGFloat, y: CGFloat) {
        guard !cardFlying, !showConnectedMoment, !isMe, !isMatched else { return }
        // Dikey niyet scroll'un; yatay niyet netse kart oynar.
        guard cardDragging || ProfileGestureDecision.deckClaimsPan(x: x, y: y) else { return }
        cardDragging = true
        // İstek zaten gittiyse sağa direnç: kart 40pt'den öteye gitmez.
        let sinir: CGFloat = allowsMatchRequest ? .infinity : 40
        cardOffset = x > 0 ? min(x, sinir) : x
    }

    private func cardDragEnded(x: CGFloat, y: CGFloat, predictedX: CGFloat) {
        guard cardDragging else { return }
        cardDragging = false
        if ProfileGestureDecision.requestsMatch(x: max(x, predictedX), y: y, enabled: allowsMatchRequest) {
            commitConnect()
        } else if ProfileGestureDecision.dismissesCard(x: min(x, predictedX), y: y, enabled: true) {
            flyOffAndClose()
        } else {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.interactive) { cardOffset = 0 }
        }
    }

    /// Sağa: kart sağdan uçar (istek gitti), ortada onay belirir, kart yeni
    /// hâliyle ("İstek gönderildi") sağdan geri süzülür.
    private func commitConnect() {
        Haptics.success()
        cardFlying = true
        Task { await sendRightSwipe() }
        guard !reduceMotion else {
            cardFlying = false
            cardOffset = 0
            return
        }
        withAnimation(.easeIn(duration: 0.22)) { cardOffset = 700 }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(BondTheme.Motion.bouncy) { showSentBurst = true }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(BondTheme.Motion.smooth) { showSentBurst = false }
            cardFlying = false
            withAnimation(BondTheme.Motion.bouncy) { cardOffset = 0 }
        }
    }

    /// Sola: kart soldan uçar, sheet kapanır. Kayıt sessiz: kimse görmez, kurucu
    /// kendi kartında görür.
    private func flyOffAndClose() {
        cardFlying = true
        Haptics.selection()
        if !isMe { appState.recordLeftSwipe(on: profile) }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.28)) { cardOffset = -800 }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 260))
            dismiss()
        }
    }

    /// Bağlantı anı: iki avatar kısa ve belirgin biçimde yaklaşır, sonra sohbet.
    private func presentConnectedMoment(then matchID: UUID) async {
        withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { showConnectedMoment = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 100))
        withAnimation(reduceMotion ? nil : BondTheme.Motion.bouncy) { avatarsTogether = true }
        // Halka, rozet ve yazı otursun diye biraz daha uzun; sonra sohbet.
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 450 : 1300))
        withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { showConnectedMoment = false }
        conversationRoute = ConversationRoute(id: matchID)
    }

    /// Kaydırırken kartın köşesinde beliren damga: sağa çekince sağ üstte turuncu
    /// "BAĞLAN", sola çekince sol üstte "KAPAT". Çektikçe belirir, hafif eğik.
    @ViewBuilder private func swipeStamp(right: Bool) -> some View {
        let aktif = (cardDragging || cardFlying) && (right ? (swipingRight && allowsMatchRequest) : cardOffset < 0)
        Text(right ? L10n.Introduction.connect.uppercased() : L10n.Introduction.close.uppercased())
            .font(.system(size: 26, weight: .heavy))
            .tracking(1)
            .foregroundStyle(right ? BondTheme.burntOrange : BondTheme.ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(right ? BondTheme.burntOrange : BondTheme.ink, lineWidth: 3))
            .rotationEffect(.degrees(right ? -12 : 12))
            .opacity(aktif ? Double(swipeProgress) : 0)
            .scaleEffect(aktif ? 0.8 + 0.2 * swipeProgress : 0.8)
            .padding(.top, 88)
            .padding(.horizontal, BondTheme.Space.xl)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// İstek gitti: ortada turuncu onay dairesi, kısa.
    private var sentBurst: some View {
        VStack(spacing: BondTheme.Space.sm) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(BondTheme.paper)
                .frame(width: 84, height: 84)
                .background(BondTheme.burntOrange, in: Circle())
            Text(L10n.CampusDesign.cardRequestSentHint)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BondTheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// "Bağlantı kuruldu" — kartın üstünde yarı saydam katman.
    private var connectedMoment: some View {
        ZStack {
            BondTheme.ink.opacity(0.35).ignoresSafeArea()
            VStack(spacing: BondTheme.Space.md) {
                ZStack {
                    // Fotoğraflar birleştiği an aralarından yayılıp sönen halka.
                    Circle()
                        .strokeBorder(BondTheme.upvote, lineWidth: 2)
                        .frame(width: 76, height: 76)
                        .keyframeAnimator(initialValue: MeetRing(), trigger: avatarsTogether) { ring, frame in
                            ring.scaleEffect(frame.scale).opacity(frame.opacity)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                LinearKeyframe(0.7, duration: 0.2)
                                CubicKeyframe(2.3, duration: 0.7)
                            }
                            KeyframeTrack(\.opacity) {
                                LinearKeyframe(0, duration: 0.2)
                                MoveKeyframe(0.75)
                                CubicKeyframe(0, duration: 0.7)
                            }
                        }
                        .allowsHitTesting(false)
                    HStack(spacing: avatarsTogether ? -18 : 28) {
                        ProfileMedia(url: nil, data: appState.avatarData, assetName: nil)
                            .frame(width: 76, height: 76).clipShape(Circle())
                            .overlay(Circle().stroke(BondTheme.paper, lineWidth: 3))
                        ProfileMedia(url: details?.avatarURL ?? profile.imageURL, data: nil, assetName: profile.imageAssetName)
                            .frame(width: 76, height: 76).clipShape(Circle())
                            .overlay(Circle().stroke(BondTheme.paper, lineWidth: 3))
                    }
                    // Birleşme noktasında beliren küçük bağlantı rozeti.
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(BondTheme.upvote, in: Circle())
                        .overlay(Circle().stroke(BondTheme.paper, lineWidth: 2.5))
                        .offset(y: 34)
                        .scaleEffect(avatarsTogether ? 1 : 0.2)
                        .opacity(avatarsTogether ? 1 : 0)
                        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy.delay(0.22), value: avatarsTogether)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 10)
                Group {
                    Text(L10n.Introduction.connected)
                        .font(BondTheme.Typography.title2)
                    Text(L10n.Introduction.connectedBody)
                        .font(BondTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                // Yazı, fotoğraflar birleşince aşağıdan yükselerek geliyor.
                .opacity(avatarsTogether || reduceMotion ? 1 : 0)
                .offset(y: avatarsTogether || reduceMotion ? 0 : 10)
                .animation(reduceMotion ? nil : BondTheme.Motion.smooth.delay(0.15), value: avatarsTogether)
            }
            .foregroundStyle(BondTheme.ink)
            .padding(BondTheme.Space.xl)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .sensoryFeedback(.success, trigger: showConnectedMoment) { _, yeni in yeni }
    }

    /// Kaydırılan kart: başlık, fotoğraf destesi, gönderiler, hakkında.
    private var cardBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                identityHeader
                gallery
                // İlgi alanları fotoğrafların hemen altında: kişiye bakınca
                // ikinci soru "neyle uğraşıyor", en altta kalınca görülmüyordu.
                interestList
                personPosts

                if let visiblePlace {
                    Label(visiblePlace.name, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                if let detailsError {
                    ScreenFailureView(message: detailsError, compact: true) {
                        Task { await reloadDetails() }
                    }
                }

                if !profile.bio.trimmed.isEmpty {
                    VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                        profileSectionTitle(L10n.CampusDesign.about)
                        Text(profile.bio).font(.body).lineSpacing(4)
                    }
                }

                meetHere
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, BondTheme.Space.lg)
            .padding(.top, BondTheme.Space.md)
            .padding(.bottom, BondTheme.Space.xl)
        }
        .accessibilityAction(named: L10n.Introduction.send) {
            guard allowsMatchRequest else { return }
            Task { await sendRightSwipe() }
        }
    }

    /// Üst çubuktaki kapat ve menü düğmeleri. Sistemin camı sayfayı açan
    /// ekranın temasını alıyor (koyu stüdyodan açılınca koyu cam, koyu simge);
    /// düğme bu yüzden zeminini kartın renginden kendisi çiziyor.
    private func cardBarGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(BondTheme.ink)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(theme == .classic ? BondTheme.surface : BondTheme.ink.opacity(0.1))
                    .shadow(color: .black.opacity(theme == .classic ? 0.08 : 0), radius: 8, y: 2)
            }
            .contentShape(Circle())
            .environment(\.colorScheme, cardScheme)
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Ad fotoğrafın yanında kalıyor: uzun ad küçülüp iki satıra iniyor.
            // Eskiden sığmayınca fotoğrafın altına düşüyor, kocaman bir satır
            // ve boşluk bırakıyordu. Alt alta düzen yalnızca çok büyük yazıda.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                    identityPortrait
                    identityCopy
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    identityPortrait
                    identityCopy
                }
            }

            connectionCue

            if kurucu {
                FounderCredLine(color: theme == .classic ? BondTheme.ember : BondTheme.ink)
                FounderContactCard(secondary: theme.secondaryText)
            }
        }
    }

    private var identityPortrait: some View {
        // Kendi kartında uygulamadaki fotoğraf: az önce değiştirdiysen yenisi,
        // sunucudan dönmesini beklemeden.
        ProfileMedia(
            url: isMe ? (appState.avatarURL ?? details?.avatarURL ?? profile.imageURL) : (details?.avatarURL ?? profile.imageURL),
            data: isMe ? appState.avatarData : nil,
            assetName: profile.imageAssetName
        )
        .frame(width: 96, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous)
                .stroke(BondTheme.hairline.opacity(0.8), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private var identityCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profile.name)
                .editorialTitle(30)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            if let username = details?.username, !username.isEmpty {
                Text("@" + username)
                    .font(BondTheme.Typography.footnote.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }

            ProfileEducationLine(
                department: profile.department,
                university: profile.university,
                year: profile.year,
                font: BondTheme.Typography.footnote,
                color: theme.secondaryText
            )

            ProfileBadgeLabel(badge: details?.badge ?? profile.badge)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    @ViewBuilder private var connectionCue: some View {
        if !isMe, !isMatched {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if alreadySwiped {
                        Label(L10n.CampusDesign.cardRequestSentHint, systemImage: "paperplane.fill")
                            .foregroundStyle(BondTheme.burntOrangeText)
                    } else {
                        swipeGuide
                    }
                }
                .font(BondTheme.Typography.caption.weight(.medium))
                .transition(.blurReplace)
                .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: alreadySwiped)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Yön ipucu: "Kapat" kartın sol kenarında, "Bağlan" sağında; hangi yöne
    /// kaydırılacağını yeri söylüyor. Kart sürüklenirken gittiği taraf
    /// koyulaşıp oku o yöne itiyor, öbür taraf soluyor: ipucu parmağı izliyor.
    private var swipeGuide: some View {
        let sol = cardOffset < 0 ? swipeProgress : 0
        let sag = cardOffset > 0 && allowsMatchRequest ? swipeProgress : 0
        return HStack(spacing: 0) {
            swipeGuideSide(right: false, active: sol, dimmed: sag)
            Spacer(minLength: BondTheme.Space.md)
            swipeGuideSide(right: true, active: sag, dimmed: sol)
        }
        .font(BondTheme.Typography.footnote.weight(.semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L10n.Introduction.swipeHintRight), \(L10n.Introduction.swipeHintLeft)")
    }

    private func swipeGuideSide(right: Bool, active: CGFloat, dimmed: CGFloat) -> some View {
        // Bağlan, klasik kartta istek damgasıyla aynı turuncu; renkli kartta
        // turuncu zemine karışacağı için kartın mürekkebi.
        let vurgu = right && theme == .classic ? BondTheme.burntOrangeText : BondTheme.ink
        return HStack(spacing: 8) {
            if !right { swipeGuideArrow("arrow.left") }
            Text(right ? L10n.Introduction.connect : L10n.Introduction.close)
            if right { swipeGuideArrow("arrow.right") }
        }
        .foregroundStyle(active > 0.05 ? vurgu : theme.secondaryText)
        .opacity(1 - 0.55 * Double(dimmed))
        .offset(x: (right ? 1 : -1) * 6 * active)
        .animation(BondTheme.Motion.snappy, value: active > 0.05)
    }

    private func swipeGuideArrow(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(.foreground.opacity(0.35), lineWidth: 1))
    }

    /// İlk birkaç açılışta kart bir kez sağa kıpırdayıp geri oturuyor: yazıyı
    /// okumadan da kartın kaydığı anlaşılsın. Üç kez; sonra bir daha yok.
    private func peekSwipeIfNeeded() async {
        guard !reduceMotion, swipePeekCount < 3 else { return }
        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled, allowsMatchRequest, !cardDragging, !cardFlying, cardOffset == 0 else { return }
        swipePeekCount += 1
        cardPeeking = true
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) { cardOffset = 28 }
        try? await Task.sleep(for: .milliseconds(380))
        if !cardDragging {
            withAnimation(.spring(duration: 0.55, bounce: 0.35)) { cardOffset = 0 }
            try? await Task.sleep(for: .milliseconds(450))
        }
        cardPeeking = false
    }

    private func profileSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(BondTheme.Typography.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(BondTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.rule).frame(height: 0.5)
            }
    }

    @ViewBuilder private var actions: some View {
        if isMe {
            EmptyView()
        } else if isMatched {
            Button { openConversation() } label: {
                Label(L10n.Introduction.openChat, systemImage: "message")
                    .font(BondTheme.Typography.body.weight(.semibold))
                    .foregroundStyle(BondTheme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(BondTheme.acid, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .sensoryFeedback(.selection, trigger: conversationRoute?.id)
        } else if kurucu {
            // Kurucuya herkes doğrudan yazabilir; bağlantı isteği beklenmez.
            VStack(spacing: 6) {
                Button {
                    Task { await openFounderChat() }
                } label: {
                    Label(L10n.Profile.sendMessage, systemImage: "message.fill")
                        .font(BondTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(BondTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(BondTheme.acid, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(isOpeningFounderChat)
                Text(L10n.Profile.messageFounderHint)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        // Bağlantı isteği düğme değil, kartı sağa kaydırmak. VoiceOver için
        // aynı iş `cardBody` üstündeki accessibilityAction'da.
    }

    private func openFounderChat() async {
        guard !isOpeningFounderChat else { return }
        isOpeningFounderChat = true
        defer { isOpeningFounderChat = false }
        if let id = await appState.openFounderChat(with: profile) {
            conversationRoute = ConversationRoute(id: id)
        }
    }

    @ViewBuilder private var meetHere: some View {
        if visiblePlace != nil, !isMe {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                // Fincan düğmesi + yanında ne olduğunu anlatan satır: kart geniş,
                // tek başına ikon burada fazla sessiz kalıyor.
                HStack(spacing: BondTheme.Space.compact) {
                    MeetupCoffeeButton(sent: pendingRequest != nil, size: 52) { sendRequest() }
                        .accessibilityLabel(pendingRequest == nil ? L10n.Profile.meetHere : L10n.Profile.requestSent)
                    Text(pendingRequest == nil ? L10n.Profile.meetHere : L10n.Profile.requestSent)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        // Düğme aynı metni okuyor; iki kez söylenmesin.
                        .accessibilityHidden(true)
                }

                if pendingRequest == nil {
                    Text(L10n.Profile.noNotifyIfIgnored)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
    }

    private func reloadDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let fetched = try await appState.service.fetchPersonDetails(profile.id)
            guard !Task.isCancelled else { return }
            details = PersonProfileData(interests: fetched.interests, galleryURLs: fetched.galleryURLs,
                                        avatarURL: fetched.avatarURL, badge: fetched.badge,
                                        posts: appState.posts.filter { $0.author.id == profile.id },
                                        username: fetched.username, cardTheme: fetched.cardTheme)
            detailsError = nil
        } catch {
            guard !appState.isCancellation(error) else { return }
            detailsError = UserFacingError.message(error, fallback: L10n.Errors.title)
        }
        let loadedPosts = await appState.personPosts(for: profile.id)
        guard !Task.isCancelled else { return }
        if details == nil {
            details = PersonProfileData(interests: profile.interests, galleryURLs: profile.galleryImageURLs,
                                        avatarURL: profile.imageURL, badge: profile.badge, posts: loadedPosts)
        } else {
            details?.posts = loadedPosts
        }
    }

    @ViewBuilder private var personPosts: some View {
        let posts = details?.posts ?? []
        if !posts.isEmpty {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                profileSectionTitle(L10n.Profile.theirPostsCaps)
                ForEach(posts) { post in
                    ProfilePostRow(post: post, dateColor: theme.secondaryText)
                }
            }
        }
    }

    private func openConversation() {
        guard let id = appState.conversationID(for: profile) else {
            appState.show(L10n.Profile.needMatchToChat)
            return
        }
        conversationRoute = ConversationRoute(id: id)
    }

    private func sendRequest() {
        guard let visiblePlace else { return }
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) {
            appState.sendMeetingRequest(to: profile, at: visiblePlace)
        }
    }
}

struct ConversationRoute: Identifiable {
    let id: UUID
}

/// Bağlantı anındaki halkanın karesi; başta görünmez.
private struct MeetRing {
    var scale: CGFloat = 0.7
    var opacity: Double = 0
}

private extension ToolbarContent {
    /// iOS 26'da çubuk düğmesinin ortak cam zemini kaldırılıyor; öncesinde
    /// zaten yok.
    @ToolbarContentBuilder
    func withoutSharedGlass() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
