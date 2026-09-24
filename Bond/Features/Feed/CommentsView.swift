import SwiftUI

struct CommentsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let postID: UUID
    @State private var draft = ""
    /// Yorum sınırına her dayanışta artar; yazma alanı titrer.
    @State private var limitBump = 0
    @State private var commentToDelete: SocialComment?
    /// Kurucu: "Oy ekle…" hedefi ve alert'teki sayı.
    @State private var boostTarget: SocialComment?
    @State private var boostInput = ""
    /// Kurucu/moderatör: bu cevaba kim ne oy vermiş.
    @State private var votersTarget: SocialComment?
    @FocusState private var focused: Bool

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && TextLimit.fits(draft, TextLimit.comment)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Gönderi sayfası: soru üstte dursun ki cevaplar
                            // bağlamsız kalmasın. Reddit'in post sayfası gibi.
                            postHeader(post)
                            if post.comments.isEmpty {
                                ContentUnavailableView(
                                    post.repliesAreAnswers ? L10n.Board.answersEmpty : L10n.Comments.empty,
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text(post.repliesAreAnswers ? L10n.Board.answersEmptyBody : L10n.Comments.emptyBody)
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(post.rankedComments) { comment in
                                    commentRow(comment, post: post)
                                }
                            }
                        }
                        .animation(reduceMotion ? nil : BondTheme.Motion.snappy,
                                   value: post.rankedComments.map(\.id))
                        .padding(.horizontal, BondTheme.Space.lg)
                        .padding(.bottom, BondTheme.Space.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom, spacing: 0) { composer }
                } else {
                    ContentUnavailableView(L10n.Comments.missingPost, systemImage: "exclamationmark.bubble")
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(post?.repliesAreAnswers == true ? L10n.Board.answersTitle : L10n.Comments.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .confirmationDialog(L10n.Comments.deleteConfirm, isPresented: Binding(
                get: { commentToDelete != nil },
                set: { if !$0 { commentToDelete = nil } }
            ), titleVisibility: .visible) {
                Button(L10n.Comments.delete, role: .destructive) {
                    guard let commentToDelete else { return }
                    appState.deleteComment(commentToDelete.id, from: postID)
                    self.commentToDelete = nil
                }
                Button(L10n.Common.cancel, role: .cancel) { commentToDelete = nil }
            } message: {
                Text(L10n.Feed.irreversible)
            }
            .alert(
                L10n.Board.boostTitle,
                isPresented: Binding(
                    get: { boostTarget != nil },
                    set: { if !$0 { boostTarget = nil } }
                ),
                presenting: boostTarget
            ) { comment in
                TextField(L10n.Board.boostPlaceholder, text: $boostInput)
                    .keyboardType(.numbersAndPunctuation)
                Button(L10n.Board.boostApply) {
                    if let n = Int(boostInput.trimmed), n != 0 {
                        appState.boostComment(postID: postID, commentID: comment.id, extra: n)
                    }
                    boostInput = ""
                }
                Button(L10n.Common.cancel, role: .cancel) { boostInput = "" }
            } message: { comment in
                Text(comment.boost > 0 ? "\(L10n.Board.boostPrompt)\n\(L10n.Board.boostCurrent(comment.boost))" : L10n.Board.boostPrompt)
            }
            .sheet(item: $votersTarget) { comment in
                PostVotersView(target: .comment(comment.id))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }

    /// Gönderinin kendisi; kartla aynı bilgi, tam metin.
    private func postHeader(_ post: SocialPost) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            HStack(spacing: BondTheme.Space.sm) {
                ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
                Text(post.author.name)
                    .font(.subheadline.weight(.semibold))
                Text(post.createdAt.relativeTurkish)
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
                Spacer()
                if post.kind != .moment { PostKindBadge(kind: post.kind) }
            }
            if !post.caption.trimmed.isEmpty {
                Text(post.caption)
                    .font(.system(size: 17, weight: .semibold))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: BondTheme.Space.md) {
                Label(L10n.Board.voteCount(post.likeCount), systemImage: "arrow.up")
                Label(
                    post.repliesAreAnswers ? L10n.Board.answerCount(post.comments.count) : L10n.Board.commentCount(post.comments.count),
                    systemImage: "bubble.left"
                )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(BondTheme.muted)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.top, BondTheme.Space.sm)
        .padding(.bottom, BondTheme.Space.lg)
        .overlay(alignment: .bottom) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private func commentRow(_ comment: SocialComment, post: SocialPost) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Fotoğraf varsa o, yoksa baş harf. Eskiden hep baş harf çiziliyordu
            // çünkü sorgu yalnızca adı getiriyordu.
            Group {
                if comment.authorAvatarURL != nil {
                    ProfileMedia(url: comment.authorAvatarURL, data: nil)
                } else {
                    Circle()
                        .fill(comment.isMine ? BondTheme.acid : BondTheme.violet.opacity(0.14))
                        .overlay {
                            Text(String(comment.author.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(comment.isMine ? BondTheme.onAccent : BondTheme.ink)
                        }
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.author)
                        .font(.system(size: 14, weight: .bold))
                    Text(comment.createdAt.relativeTurkish)
                        .font(.system(size: 11))
                        .foregroundStyle(BondTheme.muted)
                }
                Text(comment.body)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                // ▲ puan ▼ — kendi cevabına oy yok (sunucu da reddeder), kapsül sönük.
                // Kurucu istisna: kendi cevabına da verir, menüden oy ekler.
                VoteControl(
                    score: comment.voteCount,
                    myVote: comment.myVote,
                    disabled: comment.isMine && !appState.isFounder,
                    onUp: { appState.voteComment(postID: post.id, commentID: comment.id, up: true) },
                    onDown: { appState.voteComment(postID: post.id, commentID: comment.id, up: false) }
                )
                .padding(.top, 4)
            }
            Spacer(minLength: 4)
            // Kurucu/moderatör sunucuda her yorumu silebiliyor; menü yalnızca
            // kendi yorumunda görünüyordu — yetki arayüzde eksikti.
            Menu {
                if !comment.isMine {
                    Menu {
                        ForEach(ReportReason.allCases) { reason in
                            Button(reason.title) {
                                appState.reportContent(.init(kind: .comment, id: comment.id), reason: reason)
                            }
                        }
                    } label: {
                        Label(L10n.Common.report, systemImage: "flag")
                    }
                }
                // Gönderi sahibi de kendi gönderisindeki cevabı kaldırabilir (sunucu kuralı).
                if comment.isMine || post.isMine || appState.isModerator {
                    Button(
                        comment.isMine ? L10n.Comments.delete : L10n.Moderation.removeComment,
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        commentToDelete = comment
                    }
                }
                // Kurucu: cevaba oy ekle / eklenenleri geri al. Moderatör: oy
                // verenler. Kapı sunucuda; burası menüyü sade tutmak için.
                if appState.isModerator {
                    Divider()
                    if appState.isFounder {
                        Button(L10n.Board.boostTitle, systemImage: "arrow.up.circle") {
                            boostTarget = comment
                        }
                        if comment.boost > 0 {
                            Button(L10n.Board.boostClear, systemImage: "arrow.uturn.backward") {
                                appState.boostComment(postID: post.id, commentID: comment.id, extra: -comment.boost)
                            }
                        }
                    }
                    Button(L10n.Board.voters, systemImage: "person.2") {
                        votersTarget = comment
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.Comments.options)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField(post?.repliesAreAnswers == true ? L10n.Board.answerPlaceholder : L10n.Comments.placeholder, text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BondTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .composerLimit(text: $draft, limit: TextLimit.comment, bump: $limitBump)
            SendArrowButton(canSend: canSend, accessibilityLabel: L10n.Comments.sendA11y, action: send)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private func send() {
        guard canSend else { return }
        appState.addComment(draft, to: postID)
        draft = ""
        focused = true
    }
}
