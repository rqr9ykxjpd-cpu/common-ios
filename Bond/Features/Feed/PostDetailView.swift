import SwiftUI

/// Gönderi sayfası — Reddit ve X'teki gibi: akıştan sağdan itilerek açılır,
/// gönderi üstte tam hâliyle (akıştaki kartın kendisi: oy, kaydet, paylaş,
/// menü), altında cevaplar, en altta yazma alanı. Eskiden "Yorumlar" başlıklı
/// bir sheet'ti; gönderi küçük bir özetti, fotoğrafı ve oyu yoktu.
struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let postID: UUID
    /// Sheet olarak açıldıysa (kendi profilinden) sağ üstte "Bitti".
    var showsClose = false
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
    @State private var selectedAuthor: StudentProfile?

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && TextLimit.fits(draft, TextLimit.comment)
    }

    var body: some View {
        Group {
            if let post {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        PostCard(
                            post: post,
                            toggleLike: { appState.toggleLike(postID: post.id) },
                            toggleSaved: { appState.toggleSaved(postID: post.id) },
                            openProfile: { selectedAuthor = post.author },
                            delete: {
                                appState.deletePost(post.id)
                                dismiss()
                            },
                            isDetail: true,
                            onReply: { focused = true }
                        )
                        .padding(.top, BondTheme.Space.sm)
                        .padding(.bottom, BondTheme.Space.lg)
                        repliesHeader(post)
                        if post.comments.isEmpty {
                            AppEmptyState(
                                systemImage: "bubble.left.and.bubble.right",
                                title: post.repliesAreAnswers ? L10n.Board.answersEmpty : L10n.Comments.empty,
                                message: post.repliesAreAnswers ? L10n.Board.answersEmptyBody : L10n.Comments.emptyBody
                            )
                            .padding(.top, BondTheme.Space.md)
                            .padding(.horizontal, 20)
                        } else {
                            ForEach(post.rankedComments) { comment in
                                commentRow(comment, post: post)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .animation(reduceMotion ? nil : BondTheme.Motion.snappy,
                               value: post.rankedComments.map(\.id))
                    .padding(.bottom, BondTheme.Space.xl)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            } else {
                AppEmptyState(systemImage: "exclamationmark.bubble", title: L10n.Comments.missingPost)
            }
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .navigationTitle(L10n.Board.postTitle)
        .modifier(FounderPresentations())
        .onAppear { appState.openPostPages += 1 }
        .onDisappear { appState.openPostPages = max(0, appState.openPostPages - 1) }
        .navigationBarTitleDisplayMode(.inline)
        // Sekme çubuğu açık kalıyor (X'teki gibi); yazma alanı onun üstünde.
        // Gizleyip geri açmak iOS 26'da çubuğun camını bozuyordu: dönüşte
        // seçili sekme okunmuyordu.
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
        .sheet(item: $selectedAuthor) { author in
            NavigationStack {
                ProfilePhotoStackView(profile: author)
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

    /// Cevapların başlığı ve kartla cevapları ayıran çizgi. Sayı kartın cevap
    /// düğmesinde zaten yazıyor; burada tekrar etmiyor.
    private func repliesHeader(_ post: SocialPost) -> some View {
        Text(post.repliesAreAnswers ? L10n.Board.answersTitle : L10n.Comments.title)
            .font(BondTheme.Typography.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(BondTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, BondTheme.Space.md)
            .padding(.bottom, BondTheme.Space.xs)
            .overlay(alignment: .top) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
            .accessibilityAddTraits(.isHeader)
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
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(comment.isMine ? BondTheme.onAccent : BondTheme.ink)
                        }
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(comment.author)
                        .font(.subheadline.weight(.bold))
                    Text(comment.createdAt.relativeTurkish)
                        .font(.caption2)
                        .foregroundStyle(BondTheme.muted)
                }
                Text(comment.body)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                // ▲ puan ▼ — kendi cevabına oy yok (sunucu da reddeder), kapsül sönük.
                // Kurucu istisna: kendi cevabına da verir, menüden oy ekler.
                VoteControl(
                    score: comment.voteCount,
                    myVote: comment.myVote,
                    disabled: comment.isMine && !appState.isFounder,
                    onBlockedTap: { appState.show(L10n.Board.ownReplyVote) },
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
                .font(.subheadline)
                .lineLimit(1...4)
                .focused($focused)
                // Kilitliyken yorum kutusuna dokununca klavye yerine doğrulama penceresi.
                .onChange(of: focused) { _, yeni in
                    guard yeni, appState.isEduLocked else { return }
                    focused = false
                    appState.presentEduGate(.action)
                }
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
