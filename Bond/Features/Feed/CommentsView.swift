import SwiftUI

struct CommentsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let postID: UUID
    @State private var draft = ""
    @State private var commentToDelete: SocialComment?
    @FocusState private var focused: Bool

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if post.comments.isEmpty {
                                ContentUnavailableView(
                                    L10n.Comments.empty,
                                    systemImage: "bubble.left.and.bubble.right",
                                    description: Text(L10n.Comments.emptyBody)
                                )
                                .padding(.top, 64)
                            } else {
                                ForEach(post.comments) { comment in
                                    commentRow(comment)
                                }
                            }
                        }
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
            .navigationTitle(L10n.Comments.title)
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
        }
    }

    private func commentRow(_ comment: SocialComment) -> some View {
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
            }
            Spacer(minLength: 4)
            if comment.isMine {
                Menu {
                    Button(L10n.Comments.delete, systemImage: "trash", role: .destructive) {
                        commentToDelete = comment
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Comments.options)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField(L10n.Comments.placeholder, text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BondTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button { send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BondTheme.paper)
                    .frame(width: 44, height: 44)
                    .background(canSend ? BondTheme.ink : BondTheme.ink.opacity(0.22), in: Circle())
            }
            .disabled(!canSend)
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Comments.sendA11y)
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

