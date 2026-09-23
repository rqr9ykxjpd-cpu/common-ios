import SwiftUI

struct PremiumMatchesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var close: (() -> Void)?
    var showsCloseButton: Bool
    @State private var acceptingIntroduction: UUID?
    @State private var introductionConversation: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Liste ilk açılışta yerine oturdu mu; sonra `settleIn` kapanır.
    @State private var listSettled = false

    private var sortedConversations: [Conversation] {
        appState.conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    init(showsCloseButton: Bool = true, close: (() -> Void)? = nil) {
        self.close = close
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    introductions
                    acceptedIntroductions
                    yanitIstekleriSatiri
                    AppSectionHeader(title: L10n.Chat.messages)
                    if let error = appState.conversationsError {
                        ScreenFailureView(message: error, compact: !appState.conversations.isEmpty) {
                            Task { await appState.loadConversations() }
                        }
                    }
                    if appState.conversations.isEmpty, appState.isLoadingConversations {
                        // Yüklenirken "henüz sohbetin yok" yazıyordu.
                        VStack(spacing: 0) { ForEach(0..<4, id: \.self) { _ in SkeletonRow() } }
                            .padding(.horizontal, BondTheme.Space.lg)
                    } else if appState.conversations.isEmpty && appState.conversationsError == nil {
                        emptyConversations
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedConversations.enumerated()), id: \.element.id) { index, conversation in
                                VStack(spacing: 0) {
                                    NavigationLink {
                                        ConversationView(conversationID: conversation.id)
                                    } label: {
                                        conversationRow(conversation)
                                    }
                                    .buttonStyle(PressableStyle())
                                    Divider().overlay(BondTheme.hairline)
                                }
                                .settleIn(index: index, active: !listSettled)
                            }
                        }
                        // Yeni mesaj gelen sohbet en üste bir anda sıçramıyor, kayıyor.
                        .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: sortedConversations.map(\.id))
                        .task {
                            try? await Task.sleep(for: .seconds(1.2))
                            listSettled = true
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .refreshable {
                await appState.loadConversations()
                await appState.loadMessageRequests(silently: true)
                await appState.loadNotifications()
            }
            .task {
                // Sohbet ve mesaj istekleri kişi listesinden bağımsız yüklenir.
                async let conversations: Void = appState.loadConversations()
                async let requests: Void = appState.loadMessageRequests(silently: true)
                _ = await (conversations, requests)
                await appState.loadNotifications()
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Chat.title)
            .navigationDestination(item: $introductionConversation) { id in
                ConversationView(conversationID: id)
            }
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Common.close) { close?() ?? dismiss() }
                    }
                }
            }
        }
    }

    /// Kaydırmalar görünmez: tek yönlü sağa kaydırma artık adlı istek olarak
    /// listelenmez; yalnızca karşılıklı olunca bağlantı + sohbet oluşur.
    /// Sunucu da boş döndürüyor; bu bölüm güvenlik payı olarak kapalı.
    @ViewBuilder private var introductions: some View {
        if false, let error = appState.introductionRequestsError {
            ScreenFailureView(message: error, compact: true) {
                Task { await appState.loadIntroductionRequests() }
            }
        }
        if false, !appState.introductionRequests.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Introduction.requests).font(.headline)
                ForEach(appState.introductionRequests) { person in
                    VStack(alignment: .leading, spacing: 8) {
                        NavigationLink {
                            SocialPersonDetailView(profile: person, place: nil)
                        } label: {
                            HStack(spacing: 12) {
                                ProfileMedia(url: person.imageURL, data: nil, assetName: person.imageAssetName)
                                    .frame(width: 44, height: 44).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.name).font(.headline)
                                    Text(L10n.Introduction.incoming).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(BondTheme.ink)
                        }
                        Button {
                            acceptingIntroduction = person.id
                            Task {
                                let result = await appState.sendRightSwipe(to: person)
                                if case .matched(let id) = result {
                                    introductionConversation = id
                                } else if case .sent = result {
                                    // A stale request must not look like an accepted connection.
                                    await appState.loadIntroductionRequests()
                                }
                                acceptingIntroduction = nil
                            }
                        } label: {
                            HStack {
                                if acceptingIntroduction == person.id { ProgressView() }
                                Text(L10n.Chat.accept)
                            }.frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(BondTheme.ink)
                        .disabled(acceptingIntroduction != nil)
                        .accessibilityIdentifier("chat.acceptIntroduction.\(person.id)")
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder private var acceptedIntroductions: some View {
        ForEach(appState.unreadConnectionNotifications) { notification in
            if let id = notification.conversationID {
                Button {
                    appState.markNotificationRead(notification.id)
                    introductionConversation = id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.actor?.name ?? L10n.Common.someone).font(.headline)
                            Text(L10n.Introduction.accepted).font(.subheadline)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .foregroundStyle(BondTheme.ink)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat.acceptedIntroduction")
            }
        }
    }

    /// Eşleşmediğin kişilerden gelen istekler. Yalnızca bekleyen varken
    /// görünüyor: boş bir satır her açılışta yer kaplar ve okunmaz hale gelir.
    /// Bildirimi kaçıran kişi kendisine yazıldığını başka türlü öğrenemiyordu.
    @ViewBuilder private var yanitIstekleriSatiri: some View {
        let bekleyen = appState.pendingMessageRequests
        if let error = appState.messageRequestsError {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.ScreenStates.requests).font(.headline)
                ScreenFailureView(message: error, compact: true) {
                    Task { await appState.loadMessageRequests(silently: true) }
                }
            }
        } else if appState.isLoadingMessageRequests && bekleyen.isEmpty {
            ProgressView(L10n.ScreenStates.requests).font(.subheadline)
        }
        if !bekleyen.isEmpty {
            NavigationLink {
                MessageRequestsView()
            } label: {
                HStack(spacing: BondTheme.Space.md) {
                    Image(systemName: "tray.full.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(BondTheme.violet)
                        .frame(width: 38, height: 38)
                        .background(BondTheme.violet.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bekleyen.count == 1 ? L10n.Chat.oneRequest : L10n.Chat.requestCount(bekleyen.count))
                            .font(.headline)
                            .foregroundStyle(BondTheme.ink)
                        Text(L10n.Chat.fromUnmatched)
                            .font(.footnote)
                            .foregroundStyle(BondTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                }
                .padding(BondTheme.Space.md)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous).stroke(BondTheme.hairline))
                .contentShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }


    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: BondTheme.Space.md) {
            ProfileMedia(url: conversation.profile.imageURL, data: nil, assetName: conversation.profile.imageAssetName)
                .frame(width: 54, height: 54)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.profile.name)
                        .font(.headline.weight(conversation.unreadCount > 0 ? .bold : .regular))
                    Spacer()
                    Text(conversation.updatedAt.shortTimeTurkish)
                        .font(.caption)
                        .foregroundStyle(BondTheme.muted)
                }
                HStack {
                    Text(conversation.lastMessage)
                        .font(.subheadline.weight(conversation.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(conversation.unreadCount > 0 ? BondTheme.ink : BondTheme.muted)
                        .lineLimit(2)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(BondTheme.paper)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(BondTheme.ink, in: Capsule())
                            .contentTransition(.numericText(value: Double(conversation.unreadCount)))
                            // Sohbeti okuyup dönünce rozet yerinde sönüyor.
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .accessibilityLabel(L10n.ScreenStates.unread(conversation.unreadCount))
                    }
                }
                .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: conversation.unreadCount)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.vertical, BondTheme.Space.md)
        .contentShape(Rectangle())
    }

    private var emptyConversations: some View {
        VStack(spacing: BondTheme.Space.sm) {
            Image(systemName: "message")
                .font(.system(size: 22))
                .foregroundStyle(BondTheme.muted)
            Text(L10n.Chat.emptyTitle)
                .font(.system(size: 15, weight: .semibold))
            Text(L10n.Chat.emptyBody)
                .font(.system(size: 13))
                .foregroundStyle(BondTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BondTheme.Space.xxl)
    }
}
