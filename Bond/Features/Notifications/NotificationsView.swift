import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProfile: StudentProfile?
    @State private var showMessageRequests = false
    @State private var showMeetingRequests = false
    @State private var conversationRoute: NotificationConversationRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    Text(L10n.Notification.intro)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                    if appState.notifications.isEmpty {
                        notificationState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.notifications.sorted(by: { $0.createdAt > $1.createdAt })) { notification in
                                Button { open(notification) } label: {
                                    notificationRow(notification)
                                }
                                .buttonStyle(PressableStyle())
                                .contextMenu {
                                    if !notification.isRead {
                                        Button(L10n.Notification.markRead) {
                                            appState.markNotificationRead(notification.id)
                                        }
                                    }
                                }
                                Divider().overlay(BondTheme.hairline)
                            }
                        }
                    }
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.top, BondTheme.Space.md)
                .padding(.bottom, BondTheme.Space.xxl)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .refreshable { await appState.loadNotifications() }
            .task {
                // Eski bildirimlerde sohbet kimliği olmayabilir. Liste görünmeden
                // sohbetleri yükleyerek kişi bazlı güvenli fallback'i hazır tutuyoruz.
                // Bildirimler zaten akışta yüklüyse burada tekrar çekmek, satıra
                // basıp okundu yaptıktan hemen sonra rozeti geri getiriyordu.
                async let conversations: Void = appState.loadConversations()
                if appState.notifications.isEmpty {
                    async let notifications: Void = appState.loadNotifications()
                    _ = await (conversations, notifications)
                } else {
                    await conversations
                }
                // Listeye bakmak = görüldü. Satıra basmadan kapanınca rozet
                // "1" diye kalıyordu; açılınca hepsini okundu sayıyoruz.
                if appState.unreadNotificationCount > 0 {
                    appState.markAllNotificationsRead()
                }
            }
            .navigationTitle(L10n.Notification.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showMessageRequests) {
                MessageRequestsView()
            }
            .sheet(item: $selectedProfile) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
                }
            }
            .sheet(isPresented: $showMeetingRequests) {
                MeetingRequestsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .fullScreenCover(item: $conversationRoute) { route in
                NavigationStack { ConversationView(conversationID: route.id, showsClose: true) }
            }
        }
    }

    @ViewBuilder
    private var notificationState: some View {
        if appState.isLoadingNotifications {
            AppLoadingView()
        } else if let error = appState.notificationsError {
            ContentUnavailableView {
                Label(L10n.Errors.title, systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button(L10n.Common.retry) {
                    Task { await appState.loadNotifications() }
                }
                .buttonStyle(.borderedProminent)
                .tint(BondTheme.acid)
            }
        } else {
            ContentUnavailableView(
                L10n.Notification.empty,
                systemImage: "bell",
                description: Text(L10n.Notification.emptyBody)
            )
        }
    }


    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: BondTheme.Space.md) {
            ZStack(alignment: .bottomTrailing) {
                if let actor = notification.actor {
                    ProfileMedia(url: actor.imageURL, data: nil, assetName: actor.imageAssetName)
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    Image(systemName: notification.kind.systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(BondTheme.violet)
                        .frame(width: 54, height: 54)
                        .background(BondTheme.violet.opacity(0.1), in: Circle())
                }
                Image(systemName: notification.kind.systemName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(kindColor(notification.kind), in: Circle())
                    .overlay(Circle().stroke(BondTheme.paper, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                Text(notification.title)
                    .font(BondTheme.Typography.subheadline.weight(notification.isRead ? .semibold : .bold))
                    .foregroundStyle(BondTheme.ink)
                Text(notification.body)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text(notification.createdAt.relativeTurkish)
                    .font(BondTheme.Typography.caption)
                    .foregroundStyle(BondTheme.muted)
            }
            Spacer(minLength: BondTheme.Space.sm)
            if !notification.isRead {
                Circle()
                    .fill(BondTheme.violet)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, BondTheme.Space.md)
        .contentShape(Rectangle())
    }

    private func open(_ notification: AppNotification) {
        appState.markNotificationRead(notification.id)
        if notification.kind == .meetingRequest {
            showMeetingRequests = true
            return
        }

        if notification.kind == .message {
            if let conversationID = notification.conversationID
                ?? notification.actor.flatMap({ appState.conversationID(for: $0) }) {
                conversationRoute = NotificationConversationRoute(id: conversationID)
            } else {
                // Eşleşme kimliği olmayan `message`, backend'de yanıt isteğidir.
                showMessageRequests = true
            }
            return
        }

        guard let actor = notification.actor else {
            appState.show(notification.body)
            return
        }
        if notification.kind == .match {
            if let conversationID = notification.conversationID
                ?? appState.conversationID(for: actor) {
                conversationRoute = NotificationConversationRoute(id: conversationID)
            } else {
                selectedProfile = actor
            }
        } else {
            selectedProfile = actor
        }
    }

    private func kindColor(_ kind: AppNotificationKind) -> Color {
        switch kind {
        case .like: BondTheme.coral
        case .comment, .message: BondTheme.violet
        case .match: Color.green
        case .club: BondTheme.ink
        case .meetingRequest: BondTheme.coral
        }
    }
}

private struct NotificationConversationRoute: Identifiable {
    let id: UUID
}
