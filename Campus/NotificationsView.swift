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
                VStack(alignment: .leading, spacing: CampusTheme.Space.lg) {
                    Text("Common'daki son hareketler")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(CampusTheme.muted)
                    if appState.notifications.isEmpty {
                        ContentUnavailableView(
                            "Henüz bildirim yok",
                            systemImage: "bell",
                            description: Text("Yeni etkileşimler burada görünecek.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CampusTheme.Space.xxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(appState.notifications.sorted(by: { $0.createdAt > $1.createdAt })) { notification in
                                Button { open(notification) } label: {
                                    notificationRow(notification)
                                }
                                .buttonStyle(PressableStyle())
                                .contextMenu {
                                    if !notification.isRead {
                                        Button("Okundu olarak işaretle") {
                                            appState.markNotificationRead(notification.id)
                                        }
                                    }
                                }
                                Divider().overlay(CampusTheme.hairline)
                            }
                        }
                    }
                }
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.top, CampusTheme.Space.md)
                .padding(.bottom, CampusTheme.Space.xxl)
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .refreshable { await appState.loadNotifications() }
            .task { await appState.loadNotifications() }
            .navigationTitle("Bildirimler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
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
                    .presentationCornerRadius(30)
            }
            .fullScreenCover(item: $conversationRoute) { route in
                NavigationStack { ConversationView(conversationID: route.id) }
            }
        }
    }


    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: CampusTheme.Space.md) {
            ZStack(alignment: .bottomTrailing) {
                if let actor = notification.actor {
                    ProfileMedia(url: actor.imageURL, data: nil, assetName: actor.imageAssetName)
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    Image(systemName: notification.kind.systemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CampusTheme.violet)
                        .frame(width: 54, height: 54)
                        .background(CampusTheme.violet.opacity(0.1), in: Circle())
                }
                Image(systemName: notification.kind.systemName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(kindColor(notification.kind), in: Circle())
                    .overlay(Circle().stroke(CampusTheme.paper, lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.system(size: 14, weight: notification.isRead ? .semibold : .bold, design: .rounded))
                    .foregroundStyle(CampusTheme.ink)
                Text(notification.body)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
                    .lineLimit(2)
                Text(notification.createdAt.relativeTurkish)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
            Spacer(minLength: CampusTheme.Space.sm)
            if !notification.isRead {
                Circle()
                    .fill(CampusTheme.violet)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, CampusTheme.Space.md)
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
        case .like: CampusTheme.coral
        case .comment, .message: CampusTheme.violet
        case .match: Color.green
        case .club: CampusTheme.ink
        case .meetingRequest: CampusTheme.coral
        }
    }
}

private struct NotificationConversationRoute: Identifiable {
    let id: UUID
}

private struct MeetingRequestRoute: Identifiable {
    let id: UUID
}
