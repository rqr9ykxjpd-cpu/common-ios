import SwiftUI

/// Akış kartı — Reddit modeli: yazı önde, fotoğraf varsa küçük, altta ▲ oy ve
/// cevap sayısı. Insta düzeni (tam boy fotoğraf, kalp, "34 beğeni") kalktı;
/// ekranda bir gönderi yerine beş altı gönderi okunuyor.
struct PostCard: View {
    @Environment(AppState.self) private var appState
    let post: SocialPost
    let toggleLike: () -> Void
    let toggleSaved: () -> Void
    let openProfile: () -> Void
    let delete: () -> Void
    /// Akış verirse avatar, açılan kişi kartına zoom ile büyür.
    var zoomNamespace: Namespace.ID? = nil
    /// Gönderi sayfasının başındaki hâli: tam metin, fotoğraf kendi oranında,
    /// en iyi cevap özeti yok (cevaplar hemen altta).
    var isDetail = false
    /// Gönderi sayfasını açar (akış itiyor). Verilmezse sayfa sheet olarak açılır.
    var openPost: (() -> Void)? = nil
    /// Gönderi sayfasında cevap düğmesi: yazma alanına odaklanır.
    var onReply: (() -> Void)? = nil
    @State private var showComments = false
    /// Gönderi sayfasında fotoğrafın gerçek boyutu; oran buradan.
    @State private var imageSize: CGSize?
    @State private var showDeleteConfirmation = false
    @State private var showModeratorRemove = false
    @State private var showBlockConfirmation = false
    private var hasImage: Bool {
        post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil
    }

    /// Akışta bütün görseller sabit 4:3 alanda durur. Uzak görsel indikten sonra
    /// kartın boyu değişmez; liste aşağı-yukarı sıçramaz. Tam görsel detayda açılır.
    private let imageAspect: CGFloat = 0.75

    /// İkinci satır: yer varsa yer, yoksa bölüm ve sınıf; sonunda zaman.
    private var metaLine: String {
        var parcalar: [String] = []
        if post.isPinned { parcalar.append(L10n.Board.pinnedAt(post.pinSlot)) }
        if let place = post.place {
            parcalar.append(place.name)
        } else {
            let bolum = [post.author.department, AcademicYear.display(post.author.year)].filter { !$0.isEmpty }
            parcalar.append(bolum.isEmpty ? post.author.university : bolum.joined(separator: " · "))
        }
        parcalar.append(post.createdAt.relativeTurkish)
        return parcalar.joined(separator: " · ")
    }

    private var replyCountText: String {
        post.repliesAreAnswers ? L10n.Board.answerCount(post.comments.count) : L10n.Board.commentCount(post.comments.count)
    }

    private func open() {
        if let openPost { openPost() } else { showComments = true }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            header
            content
            if !isDetail, let top = post.topComment, top.voteCount >= 0 {
                topReply(top)
            }
            actions
        }
        .padding(.horizontal, 20)
        // Erişilebilirlik boyutlarında kapsül sırası taşıyordu; kart bir üst
        // sınırda durur, sistem geri kalanını büyütür.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Gönderi sayfası kartın kendisinden büyüyerek açılır, kapanınca yerine döner.
        .zoomSource(id: "gonderi-\(post.id)", in: zoomNamespace)
        .sheet(isPresented: $showComments) {
            NavigationStack { PostDetailView(postID: post.id, showsClose: true) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .zoomTransition(sourceID: "gonderi-\(post.id)", in: zoomNamespace)
        }
        .confirmationDialog(L10n.Moderation.removePostConfirm, isPresented: $showModeratorRemove, titleVisibility: .visible) {
            Button(L10n.Moderation.removePost, role: .destructive) {
                Task { await appState.moderatorRemovePost(post.id) }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Moderation.removePostBody)
        }
        .confirmationDialog(L10n.Feed.deletePostConfirm, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.Feed.deletePost, role: .destructive, action: delete)
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Feed.irreversible)
        }
        .confirmationDialog(
            L10n.Chat.blockConfirm(post.author.name),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Feed.blockUser, role: .destructive) {
                appState.block(post.author)
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Chat.blockBody)
        }
    }

    // MARK: - Parçalar

    private var header: some View {
        HStack(spacing: BondTheme.Space.compact) {
            Button(action: openProfile) {
                HStack(spacing: BondTheme.Space.compact) {
                    ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .zoomSource(id: "yazar-\(post.id)", in: zoomNamespace)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: BondTheme.Space.xs) {
                            Text(post.author.name)
                                .font(Font.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .layoutPriority(1)
                            if let icon = post.author.badge.systemImage {
                                Image(systemName: icon)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(post.author.badge == .founder ? BondTheme.ember : BondTheme.icon)
                                    .accessibilityLabel(post.author.badge.title ?? "")
                            }
                        }
                        Text(metaLine)
                            .font(Font.caption)
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(BondTheme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Feed.openProfile(post.author.name))
            Spacer(minLength: 0)
            menu
        }
    }

    private var menu: some View {
        Menu {
            ShareLink(item: "\(post.author.name): \(post.caption)") {
                Label(L10n.Feed.share, systemImage: "square.and.arrow.up")
            }
            if post.isMine {
                Button(L10n.Feed.deletePost, systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
            if !post.isMine {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.title) {
                            appState.reportContent(.init(kind: .post, id: post.id), reason: reason)
                        }
                    }
                } label: {
                    Label(L10n.Common.report, systemImage: "flag")
                }
                Button(L10n.Feed.blockUser, role: .destructive) {
                    showBlockConfirmation = true
                }
                // Moderasyon eylemleri yalnızca rozetli hesapta görünür.
                // Asıl kapı sunucudaki izin kuralı; buradaki kontrol
                // sadece menüyü kalabalıklaştırmamak için.
                if appState.isModerator {
                    Divider()
                    Button(L10n.Moderation.removePost, systemImage: "trash.slash", role: .destructive) {
                        showModeratorRemove = true
                    }
                }
            }
            // Kurucu: oy ekle / sabitle. Moderatör: oy verenler. Kapı sunucuda;
            // burası sadece menüyü ilgisiz hesapta kalabalıklaştırmamak için.
            if appState.isModerator {
                Divider()
                if appState.isFounder {
                    Button(L10n.Board.boostTitle, systemImage: "arrow.up.circle") {
                        appState.boostPromptPostID = post.id
                    }
                    if post.boost > 0 {
                        Button(L10n.Board.boostClear, systemImage: "arrow.uturn.backward") {
                            appState.boostPost(post.id, extra: -post.boost)
                        }
                    }
                    Button(post.isPinned ? L10n.Board.pinChange : L10n.Board.pin, systemImage: "pin") {
                        appState.pinPromptPostID = post.id
                    }
                    if post.isPinned {
                        Button(L10n.Board.unpin, systemImage: "pin.slash") {
                            appState.setPostPin(post.id, slot: nil)
                        }
                    }
                }
                Button(L10n.Board.voters, systemImage: "person.2") {
                    appState.votersPostID = post.id
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(BondTheme.ink.opacity(0.5))
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel(L10n.Common.options)
    }

    /// Yazı ve varsa fotoğraf. Akışta dokununca gönderi sayfası açılır;
    /// sayfanın kendisinde düz içerik, metin seçilebilir.
    @ViewBuilder private var content: some View {
        if isDetail {
            contentBody
                .textSelection(.enabled)
        } else {
            Button(action: open) {
                contentBody.contentShape(Rectangle())
            }
            .buttonStyle(.pressableCard)
            .accessibilityLabel(post.caption)
            .accessibilityHint(L10n.Board.openPost)
        }
    }

    /// Sayfada fotoğraf kendi oranında (çok uzun/geniş olanlar sınırda);
    /// akışta sabit 4:3, liste sıçramasın.
    private var detailAspect: CGFloat {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return 1 / imageAspect }
        return min(max(imageSize.width / imageSize.height, 0.7), 1.9)
    }

    private var captionFont: Font {
        // Sayfada yazı büyür (X'teki gibi); fotoğrafsız gönderi başlık gibi durur.
        if isDetail { return hasImage ? .title3 : .title3.weight(.semibold) }
        return .body.weight(hasImage ? .medium : .semibold)
    }

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            // Rozet başlık satırından buraya indi: ad ve bölüm kesilmesin,
            // tür de metnin hemen üstünde okunsun (Reddit'in flair'i gibi).
            if post.kind != .moment {
                PostKindBadge(kind: post.kind)
            }
            if !post.caption.trimmed.isEmpty {
                Text(post.caption)
                    .font(captionFont)
                    .lineSpacing(4)
                    .lineLimit(isDetail ? nil : 6)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(BondTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: isDetail)
            }
            if hasImage {
                Color.clear
                    .aspectRatio(isDetail ? detailAspect : 1 / imageAspect, contentMode: .fit)
                    .overlay {
                        if post.localImageData != nil || post.imageAssetName != nil {
                            ProfileMedia(url: nil, data: post.localImageData,
                                         assetName: post.imageAssetName, kind: .content)
                        } else if let url = post.imageURL {
                            if isDetail {
                                MeasuredRemoteImage(url: url, naturalSize: $imageSize)
                            } else {
                                ProfileMedia(url: url, data: nil, kind: .content, showsRetry: true)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                    .onAppear {
                        guard isDetail, imageSize == nil else { return }
                        if let data = post.localImageData, let image = UIImage(data: data) {
                            imageSize = image.size
                        } else if let name = post.imageAssetName, let image = UIImage(named: name) {
                            imageSize = image.size
                        }
                    }
            }
        }
    }

    /// En çok oy alan cevap, tek bakışta. Soruyu açmadan cevabı görürsün.
    private func topReply(_ comment: SocialComment) -> some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: BondTheme.Space.sm) {
                Label(String(comment.voteCount), systemImage: "arrow.up")
                    .font(.caption.weight(.bold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(BondTheme.muted)
                    .padding(.top, 1)
                Text("**\(comment.author)**  \(comment.body)")
                    .font(.footnote)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(BondTheme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel("\(L10n.Board.topAnswer): \(comment.author), \(comment.body)")
    }

    private var actions: some View {
        HStack(spacing: BondTheme.Space.sm) {
            // ▲ çağıranın kapanışı (akış/profil aynı davranır), ▼ doğrudan AppState.
            VoteControl(
                score: post.likeCount,
                myVote: post.myVote,
                onUp: toggleLike,
                onDown: { appState.vote(postID: post.id, up: false) }
            )

            Button {
                if isDetail { onReply?() } else { open() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.footnote.weight(.semibold))
                    Text(replyCountText)
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .foregroundStyle(BondTheme.ink)
                .background(BondTheme.surface, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Feed.openComments)

            Spacer()

            ShareLink(item: "\(post.author.name): \(post.caption)") {
                Image(systemName: "paperplane")
                    .font(.body.weight(.regular))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(L10n.Feed.share)
            Button(action: toggleSaved) {
                Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                    .font(.body.weight(.regular))
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(post.saved ? L10n.Feed.removeSaved : L10n.Feed.save)
            .accessibilityAddTraits(post.saved ? .isSelected : [])
        }
        .foregroundStyle(BondTheme.ink)
    }
}
