import SwiftUI

struct PremiumMatchesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var close: (() -> Void)?

    init(close: (() -> Void)? = nil) {
        self.close = close
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CampusTheme.Space.xl) {
                    yanitIstekleriSatiri
                    newConnections
                    meetSuggestions
                    AppSectionHeader(title: L10n.Chat.messages)
                    if appState.conversations.isEmpty, appState.isLoadingConversations {
                        // Yüklenirken "henüz sohbetin yok" yazıyordu.
                        VStack(spacing: 12) {
                            ProgressView().tint(CampusTheme.violet)
                            Text(L10n.Chat.loading)
                                .font(.system(size: 13))
                                .foregroundStyle(CampusTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                    } else if appState.conversations.isEmpty {
                        emptyConversations
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.conversations.sorted(by: { $0.updatedAt > $1.updatedAt })) { conversation in
                                NavigationLink {
                                    ConversationView(conversationID: conversation.id)
                                } label: {
                                    conversationRow(conversation)
                                }
                                .buttonStyle(PressableStyle())
                                Divider().overlay(CampusTheme.hairline)
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .refreshable {
                await appState.loadConversations()
                await appState.loadMessageRequests(silently: true)
            }
            .task {
                // Kullanıcı Tanış sekmesine hiç uğramadan buraya gelebilir; o durumda
                // aday listesi boş olur ve öneri şeridi hiç görünmezdi.
                if appState.profiles.isEmpty { await appState.loadDiscovery() }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Chat.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { close?() ?? dismiss() }
                }
            }
        }
    }

    /// Eşleşmediğin kişilerden gelen istekler. Yalnızca bekleyen varken
    /// görünüyor: boş bir satır her açılışta yer kaplar ve okunmaz hale gelir.
    /// Bildirimi kaçıran kişi kendisine yazıldığını başka türlü öğrenemiyordu.
    @ViewBuilder private var yanitIstekleriSatiri: some View {
        let bekleyen = appState.pendingMessageRequests
        if !bekleyen.isEmpty {
            NavigationLink {
                MessageRequestsView()
            } label: {
                HStack(spacing: CampusTheme.Space.md) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CampusTheme.violet)
                        .frame(width: 38, height: 38)
                        .background(CampusTheme.violet.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bekleyen.count == 1 ? L10n.Chat.oneRequest : L10n.Chat.requestCount(bekleyen.count))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(CampusTheme.ink)
                        Text(L10n.Chat.fromUnmatched)
                            .font(.system(size: 12))
                            .foregroundStyle(CampusTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CampusTheme.muted)
                }
                .padding(CampusTheme.Space.md)
                .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
                .contentShape(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }


    /// Sohbeti olan kişiler. Hiç yoksa bölüm tamamen gizleniyor: eskiden boş bir
    /// başlık ve altında bomboş bir şerit kalıyordu.
    @ViewBuilder private var newConnections: some View {
        if !appState.conversations.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: L10n.Chat.newConnections)
                circleStrip(appState.conversations.map(\.profile))
            }
        }
    }

    /// Henüz sohbet etmediğin, tanışabileceğin kişiler. Uygulamaya yeni katılanlar
    /// da buraya düşüyor: gizlilik kuralı gereği bir hesap gönderi paylaşana kadar
    /// doğrudan okunamıyor, tanışma adayları ise sunucudaki
    /// `get_discovery_candidates` üzerinden geldiği için yeni hesaplar görünebiliyor.
    @ViewBuilder private var meetSuggestions: some View {
        let sohbetEdilenler = Set(appState.conversations.map(\.profile.id))
        let oneriler = appState.profiles.filter { !sohbetEdilenler.contains($0.id) }
        if !oneriler.isEmpty {
            VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
                AppSectionHeader(title: L10n.Chat.peopleToMeet)
                circleStrip(Array(oneriler.prefix(12)))
            }
        }
    }

    private func circleStrip(_ profiles: [StudentProfile]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CampusTheme.Space.md) {
                ForEach(profiles) { profile in
                    NavigationLink {
                        SocialPersonDetailView(profile: profile, place: nil)
                    } label: {
                        VStack(spacing: 7) {
                            ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                                .frame(width: 68, height: 68)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(CampusTheme.violet, lineWidth: 2))
                            Text(profile.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CampusTheme.ink)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: CampusTheme.Space.md) {
            ProfileMedia(url: conversation.profile.imageURL, data: nil, assetName: conversation.profile.imageAssetName)
                .frame(width: 54, height: 54)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.profile.name)
                        .font(.system(size: 15, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                    Spacer()
                    Text(conversation.updatedAt.shortTimeTurkish)
                        .font(.system(size: 11))
                        .foregroundStyle(CampusTheme.muted)
                }
                HStack {
                    Text(conversation.lastMessage)
                        .font(.system(size: 13, weight: conversation.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(conversation.unreadCount > 0 ? CampusTheme.ink : CampusTheme.muted)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(CampusTheme.violet, in: Circle())
                    }
                }
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(.vertical, CampusTheme.Space.md)
        .contentShape(Rectangle())
    }

    private var emptyConversations: some View {
        VStack(spacing: CampusTheme.Space.sm) {
            Image(systemName: "message")
                .font(.title2)
                .foregroundStyle(CampusTheme.muted)
            Text(L10n.Chat.emptyTitle)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Chat.emptyBody)
                .font(.system(size: 13))
                .foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CampusTheme.Space.xxl)
    }
}

