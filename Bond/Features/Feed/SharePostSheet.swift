import SwiftUI

/// Gönderinin kâğıt uçak düğmesi: gönderiyi bir bağlantıya sohbet mesajı olarak
/// yollar. Liste yalnızca mevcut sohbetler; mesajlaşma bağlantıya bağlı ve
/// gönderi yeni bir istek yolu açmıyor. Bir kişiye dokununca hemen gider, satır
/// "Gönderildi" olur; aynı ekrandan başkalarına da yollanabilir.
struct SharePostSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let post: SocialPost
    @State private var search = ""
    @State private var sending: Set<UUID> = []
    @State private var sent: Set<UUID> = []

    private var people: [Conversation] {
        let terim = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terim.isEmpty else { return appState.conversations }
        return appState.conversations.filter {
            $0.profile.name.localizedStandardContains(terim)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.conversations.isEmpty {
                    AppEmptyState(
                        systemImage: "person.2",
                        title: L10n.SharePost.emptyTitle,
                        message: L10n.SharePost.emptyBody
                    )
                    .padding(.horizontal, 24)
                } else {
                    List {
                        ForEach(people) { conversation in
                            row(conversation)
                                .listRowBackground(Color.clear)
                                // Arama alanının hemen altında çizgi olmasın.
                                .listRowSeparator(conversation.id == people.first?.id ? .hidden : .visible,
                                                  edges: .top)
                        }
                        Text(people.isEmpty ? L10n.SharePost.noResults : L10n.SharePost.footer)
                            .font(.footnote)
                            .foregroundStyle(BondTheme.muted)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                                prompt: L10n.SharePost.search)
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.SharePost.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task {
                if appState.conversations.isEmpty { await appState.loadConversations() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ conversation: Conversation) -> some View {
        let gonderildi = sent.contains(conversation.id)
        let gidiyor = sending.contains(conversation.id)
        return HStack(spacing: BondTheme.Space.md) {
            ProfileMedia(url: conversation.profile.imageURL, data: nil,
                         assetName: conversation.profile.imageAssetName)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(conversation.profile.name)
                .font(.body.weight(.medium))
                .foregroundStyle(BondTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                send(to: conversation.id)
            } label: {
                ZStack {
                    if gidiyor {
                        ProgressView()
                    } else if gonderildi {
                        Label(L10n.SharePost.sent, systemImage: "checkmark")
                    } else {
                        Text(L10n.SharePost.send)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minWidth: 96, minHeight: 34)
                .foregroundStyle(gonderildi ? BondTheme.ink : BondTheme.onAccent)
                .background(gonderildi ? BondTheme.surface : BondTheme.ink, in: Capsule())
                .contentTransition(.opacity)
            }
            .buttonStyle(.pressable)
            .disabled(gidiyor || gonderildi)
            .animation(BondTheme.Motion.snappy, value: gonderildi)
            .accessibilityIdentifier("sharePost.send.\(conversation.id)")
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func send(to conversationID: UUID) {
        sending.insert(conversationID)
        Task {
            let ok = await appState.sharePost(post.id, to: conversationID)
            sending.remove(conversationID)
            if ok { sent.insert(conversationID) }
        }
    }
}

/// Sohbet balonunun içinde paylaşılan gönderi: yazarı, yazının başı ve varsa
/// küçük fotoğrafı. Dokununca gönderi sayfası açılır. Gönderi akışta yüklü
/// değilse sunucudan getirilir; silinmiş ya da görülemiyorsa bunu söyler.
struct SharedPostPreview: View {
    @Environment(AppState.self) private var appState
    let postID: UUID
    let isMine: Bool
    let open: () -> Void
    @State private var missing = false

    private var post: SocialPost? { appState.posts.first { $0.id == postID } }

    var body: some View {
        Group {
            if let post {
                Button(action: open) { card(post) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(L10n.SharePost.openPost): \(post.author.name), \(post.caption)")
            } else if missing {
                Label(L10n.SharePost.unavailable, systemImage: "rectangle.slash")
                    .font(.footnote)
                    .foregroundStyle(isMine ? BondTheme.paper.opacity(0.7) : BondTheme.muted)
                    .padding(.vertical, 4)
            } else {
                ProgressView()
                    .tint(isMine ? BondTheme.paper : BondTheme.ink)
                    .frame(width: 220, height: 56)
            }
        }
        .task(id: postID) {
            if post == nil {
                missing = !(await appState.loadPostIfNeeded(postID))
            }
        }
    }

    private func card(_ post: SocialPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProfileMedia(url: post.author.imageURL, data: nil, assetName: post.author.imageAssetName)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                Text(post.author.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            if post.imageURL != nil || post.imageAssetName != nil || post.localImageData != nil {
                ProfileMedia(url: post.imageURL, data: post.localImageData,
                             assetName: post.imageAssetName, kind: .content)
                    .frame(width: 220, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel(L10n.SharePost.photo)
            }
            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            Text(L10n.SharePost.openPost)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isMine ? BondTheme.paper.opacity(0.72) : BondTheme.violet)
        }
        .frame(width: 220, alignment: .leading)
        .padding(10)
        .background(isMine ? BondTheme.paper.opacity(0.10) : BondTheme.paper,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isMine ? BondTheme.paper.opacity(0.18) : BondTheme.hairline)
        }
        .contentShape(Rectangle())
    }
}
