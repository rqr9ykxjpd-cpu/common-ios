import SwiftUI

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProfile: StudentProfile?
    @State private var selectedMeetingRequest: MeetingRequestRoute?
    @State private var conversationRoute: NotificationConversationRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    Text(L10n.Notification.intro)
                        .font(.system(size: 13))
                        .foregroundStyle(BondTheme.muted)
                    if appState.notifications.isEmpty {
                        ContentUnavailableView(
                            L10n.Notification.empty,
                            systemImage: "bell",
                            description: Text(L10n.Notification.emptyBody)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BondTheme.Space.xxl)
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
            .task { await appState.loadNotifications() }
            .navigationTitle(L10n.Notification.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .sheet(item: $selectedProfile) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil)
                }
            }
            .sheet(item: $selectedMeetingRequest) { route in
                MeetingRequestsView(initialRequestID: route.id)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
            .fullScreenCover(item: $conversationRoute) { route in
                NavigationStack { ConversationView(conversationID: route.id) }
            }
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

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.system(size: 14, weight: notification.isRead ? .semibold : .bold))
                    .foregroundStyle(BondTheme.ink)
                Text(notification.body)
                    .font(.system(size: 13))
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(2)
                Text(notification.createdAt.relativeTurkish)
                    .font(.system(size: 11))
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
        if notification.kind == .meetingRequest, let requestID = notification.meetingRequestID {
            selectedMeetingRequest = MeetingRequestRoute(id: requestID)
            return
        }
        guard let actor = notification.actor else {
            appState.show(notification.body)
            return
        }
        if notification.kind == .message || notification.kind == .match {
            // Sohbet henüz yüklenmemişse kişiyi açıyoruz; uydurma bir sohbete
            // yazılan mesaj sunucuda reddedilip ekrandan siliniyordu.
            if let id = appState.conversationID(for: actor) {
                conversationRoute = NotificationConversationRoute(id: id)
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

private struct MeetingRequestRoute: Identifiable {
    let id: UUID
}
