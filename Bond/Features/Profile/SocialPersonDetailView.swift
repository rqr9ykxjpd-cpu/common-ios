import SwiftUI
import UIKit

struct SocialPersonDetailView: View {
    let profile: StudentProfile
    let place: CampusPlace?
    /// Sheet'in kökü olarak açıldığında `true`. İtilerek açıldığında sistem
    /// kendi geri düğmesini koyuyor; buna ek olarak bir tane daha eklemek
    /// yan yana iki geri düğmesi bırakıyordu.
    var showsClose = false
    @Environment(AppState.self) private var appState
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
    @State private var cardDragging = false
    @State private var cardFlying = false
    @State private var showsUndo = false
    @State private var undoTask: Task<Void, Never>?
    /// Sağa kaydırma sonrası ortada beliren onay.
    @State private var showSentBurst = false
    @State private var showConnectedMoment = false
    @State private var avatarsTogether = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cardLifted: Bool { cardDragging || cardFlying }
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
        if paylasilan { return BondTheme.acid.opacity(0.5) }
        return kurucu ? BondTheme.ember.opacity(0.12) : BondTheme.ink.opacity(0.055)
    }

    private var pendingRequest: MeetingRequest? {
        guard let visiblePlace else { return nil }
        return appState.meetingRequest(for: profile, at: visiblePlace)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Kart kalkınca altındaki masa görünür.
            (cardLifted ? BondTheme.surface : BondTheme.paper)
                .ignoresSafeArea()
                .animation(BondTheme.Motion.smooth, value: cardLifted)

            cardBody
                .overlay(alignment: .topLeading) { swipeStamp(right: false) }
                .overlay(alignment: .topTrailing) { swipeStamp(right: true) }
                .background(BondTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: cardLifted ? 28 : 0, style: .continuous))
                .shadow(color: .black.opacity(0.18 * swipeProgress), radius: 24, y: 12)
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
        .safeAreaInset(edge: .bottom) {
            if !isMe {
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
                                    .foregroundStyle(BondTheme.burntOrange)
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
                .background(BondTheme.paper)
            }
        }
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
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(L10n.Common.close)
                }
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
                    Image(systemName: "ellipsis")
                }
            }
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
            await reloadDetails()
        }
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
                        .font(.system(size: 11, weight: .bold)).tracking(0.7)
                        .foregroundStyle(BondTheme.violet)
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
            ProfileGalleryStack(photos: galleryPhotos)
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
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 450 : 950))
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
                HStack(spacing: avatarsTogether ? -18 : 28) {
                    ProfileMedia(url: nil, data: appState.avatarData, assetName: nil)
                        .frame(width: 76, height: 76).clipShape(Circle())
                        .overlay(Circle().stroke(BondTheme.paper, lineWidth: 3))
                    ProfileMedia(url: details?.avatarURL ?? profile.imageURL, data: nil, assetName: profile.imageAssetName)
                        .frame(width: 76, height: 76).clipShape(Circle())
                        .overlay(Circle().stroke(BondTheme.paper, lineWidth: 3))
                }
                Text(L10n.Introduction.connected)
                    .font(BondTheme.Typography.title2)
                Text(L10n.Introduction.connectedBody)
                    .font(BondTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                identityHeader
                gallery
                personPosts

                if let visiblePlace {
                    Label(visiblePlace.name, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let detailsError {
                    ScreenFailureView(message: detailsError, compact: true) {
                        Task { await reloadDetails() }
                    }
                }

                if !profile.bio.trimmed.isEmpty {
                    VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                        Text(L10n.CampusDesign.about).font(.headline)
                        Text(profile.bio).font(.body).lineSpacing(4)
                    }
                }

                interestList
                meetHere
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, BondTheme.Space.md)
            .padding(.top, BondTheme.Space.sm)
            .padding(.bottom, BondTheme.Space.xl)
        }
        .accessibilityAction(named: L10n.Introduction.send) {
            guard allowsMatchRequest else { return }
            Task { await sendRightSwipe() }
        }
    }

    private var identityHeader: some View {
        VStack(spacing: BondTheme.Space.sm) {
            ProfileMedia(
                url: details?.avatarURL ?? profile.imageURL,
                data: nil,
                assetName: profile.imageAssetName
            )
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(profile.name)
                    .font(BondTheme.Typography.title2)
                    .multilineTextAlignment(.center)
                if !isMe, !isMatched {
                    // İki durum ayrı görünüm; blurReplace biri erirken öteki belirir.
                    Group {
                        if alreadySwiped {
                            Text(L10n.CampusDesign.cardRequestSentHint)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            // Yönler doğru: sol ok + sola kaydır kapat | sağa kaydır bağlan + sağ ok.
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left").font(.caption2.weight(.bold))
                                Text(L10n.Introduction.swipeHintLeft).font(.footnote.weight(.medium))
                                Text("·").foregroundStyle(BondTheme.hairline)
                                Text(L10n.Introduction.swipeHintRight).font(.footnote.weight(.medium))
                                Image(systemName: "arrow.right").font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(BondTheme.surface, in: Capsule())
                            .multilineTextAlignment(.center)
                        }
                    }
                    .transition(.blurReplace)
                    .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: alreadySwiped)
                }
                ProfileEducationLine(
                    department: profile.department,
                    university: profile.university,
                    year: profile.year,
                    font: BondTheme.Typography.subheadline
                )
                .foregroundStyle(.secondary)
                ProfileBadgeLabel(badge: details?.badge ?? profile.badge)
            }
            .frame(maxWidth: .infinity)

            if kurucu {
                FounderCredLine()
                FounderContactCard()
            }
        }
    }

    @ViewBuilder private var actions: some View {
        if isMe {
            EmptyView()
        } else if isMatched {
            Button { openConversation() } label: {
                Label(L10n.Introduction.openChat, systemImage: "message")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .sensoryFeedback(.selection, trigger: conversationRoute?.id)
        } else if kurucu {
            // Kurucuya herkes doğrudan yazabilir; bağlantı isteği beklenmez.
            VStack(spacing: 6) {
                Button {
                    Task { await openFounderChat() }
                } label: {
                    Label(L10n.Profile.sendMessage, systemImage: "message.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BondTheme.paper)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(BondTheme.ink, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableStyle())
                .disabled(isOpeningFounderChat)
                Text(L10n.Profile.messageFounderHint)
                    .font(.system(size: 11))
                    .foregroundStyle(BondTheme.muted)
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
                    Text(pendingRequest == nil ? L10n.Profile.meetHere : L10n.Profile.requestSent)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if pendingRequest == nil {
                    Text(L10n.Profile.noNotifyIfIgnored)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                                        posts: appState.posts.filter { $0.author.id == profile.id })
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
                Text(L10n.Profile.theirPostsCaps)
                    .font(.headline)
                ForEach(posts) { post in
                    ProfilePostRow(post: post)
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
