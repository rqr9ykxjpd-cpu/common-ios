import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProfile: StudentProfile?
    @State private var showMessageRequests = false
    @State private var showMeetingRequests = false
    @State private var conversationRoute: NotificationConversationRoute?
    /// Yorum/oy bildirimi: gönderi sayfası bu yığına itilir (Reddit/X gibi).
    @State private var openedPostID: UUID?
    @State private var showSupport = false
    @State private var pushAuthorizationStatus: UNAuthorizationStatus?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Liste ilk açılışta yerine oturdu mu; sonra `settleIn` kapanır.
    @State private var listSettled = false
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            // Liste: satır sola kaydırılınca silinir, basılı tutunca hepsi silinebilir.
            List {
                Group {
                    Text(L10n.Notification.intro)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                    if let pushAuthorizationStatus,
                       pushAuthorizationStatus == .notDetermined || pushAuthorizationStatus == .denied {
                        pushPermissionCard(status: pushAuthorizationStatus)
                    }
                    if appState.notifications.isEmpty {
                        notificationState
                    }
                }
                .listRowInsets(EdgeInsets(top: BondTheme.Space.sm, leading: BondTheme.Space.lg,
                                          bottom: BondTheme.Space.sm, trailing: BondTheme.Space.lg))
                .listRowSeparator(.hidden)
                .listRowBackground(BondTheme.paper)

                ForEach(Array(appState.notifications.sorted(by: { $0.createdAt > $1.createdAt }).enumerated()),
                        id: \.element.id) { index, notification in
                    Button { open(notification) } label: {
                        notificationRow(notification)
                    }
                    .buttonStyle(PressableStyle())
                    .settleIn(index: index, active: !listSettled)
                    .listRowInsets(EdgeInsets(top: 0, leading: BondTheme.Space.lg, bottom: 0, trailing: BondTheme.Space.lg))
                    .listRowSeparatorTint(BondTheme.hairline)
                    .listRowBackground(BondTheme.paper)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(L10n.Common.delete, systemImage: "trash", role: .destructive) {
                            appState.deleteNotification(notification.id)
                        }
                    }
                    .contextMenu {
                        if !notification.isRead {
                            Button(L10n.Notification.markRead, systemImage: "checkmark") {
                                appState.markNotificationRead(notification.id)
                            }
                        }
                        Button(L10n.Common.delete, systemImage: "trash", role: .destructive) {
                            appState.deleteNotification(notification.id)
                        }
                        Button(L10n.Inbox.deleteAll, systemImage: "trash.slash", role: .destructive) {
                            confirmDeleteAll = true
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: appState.notifications.map(\.id))
            .task {
                try? await Task.sleep(for: .seconds(1.2))
                listSettled = true
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .confirmationDialog(L10n.Inbox.deleteAllConfirm, isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button(L10n.Inbox.deleteAll, role: .destructive) { appState.deleteAllNotifications() }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Inbox.deleteAllBody)
            }
            .refreshable { await appState.loadNotifications() }
            .task {
                // İzin kartı en başta: listeden sonra gelince satırları aniden aşağı itiyordu.
                await refreshPushAuthorizationStatus()
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
                // Yeniler önce bir an vurgulu görünsün, sonra renkleri yumuşakça
                // sönsün; ekran kapanırsa uyku kesilir ve hemen okundu sayılır.
                if appState.unreadNotificationCount > 0 {
                    if !reduceMotion { try? await Task.sleep(for: .seconds(1.4)) }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) {
                        appState.markAllNotificationsRead()
                    }
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
            .navigationDestination(item: $openedPostID) { id in
                PostDetailView(postID: id)
            }
            .sheet(item: $selectedProfile) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
                }
            }
            .sheet(isPresented: $showSupport) {
                SupportInboxView()
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

    private func pushPermissionCard(status: UNAuthorizationStatus) -> some View {
        HStack(spacing: BondTheme.Space.md) {
            Image(systemName: "bell.badge")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BondTheme.ink)
                .frame(width: 42, height: 42)
                .background(BondTheme.paper, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Notification.permissionTitle)
                    .font(BondTheme.Typography.headline)
                    .foregroundStyle(BondTheme.ink)
                Text(L10n.Notification.permissionBody)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(status == .denied ? L10n.Common.openSettings : L10n.Notification.permissionAction) {
                if status == .denied {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                } else {
                    Task {
                        await appState.startPushRegistration(requestAuthorization: true)
                        await refreshPushAuthorizationStatus()
                    }
                }
            }
            .font(BondTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(BondTheme.onAccent)
            .padding(.horizontal, BondTheme.Space.compact)
            .frame(minHeight: 36)
            .background(BondTheme.acid, in: Capsule())
            .buttonStyle(PressableStyle())
        }
        .padding(BondTheme.Space.compact)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
    }

    private func refreshPushAuthorizationStatus() async {
        pushAuthorizationStatus = await UNUserNotificationCenter.current()
            .notificationSettings()
            .authorizationStatus
    }

    @ViewBuilder
    private var notificationState: some View {
        if appState.isLoadingNotifications {
            VStack(spacing: 0) { ForEach(0..<4, id: \.self) { _ in SkeletonRow() } }
                .padding(.horizontal, BondTheme.Space.lg)
        } else if let error = appState.notificationsError {
            ScreenFailureView(message: error) {
                Task { await appState.loadNotifications() }
            }
        } else {
            AppEmptyState(
                systemImage: "bell",
                title: L10n.Notification.empty,
                message: L10n.Notification.emptyBody
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
                        .font(.title3.weight(.semibold))
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
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
        .padding(.vertical, BondTheme.Space.md)
        // Okunmamış satırın hafif mor zemini; okununca söner.
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BondTheme.violet.opacity(notification.isRead ? 0 : 0.06))
                .padding(.horizontal, -10)
        }
        .contentShape(Rectangle())
    }

    private func open(_ notification: AppNotification) {
        appState.markNotificationRead(notification.id)
        if notification.kind == .support {
            showSupport = true
            return
        }
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

        // Yorum ve oy gönderiye dairse gönderinin kendisi açılır. Gönderi akışta
        // yüklü değilse (eski, silinmiş) eskisi gibi kişinin kartı.
        if notification.kind == .comment || notification.kind == .like,
           let postID = notification.postID,
           appState.posts.contains(where: { $0.id == postID }) {
            openedPostID = postID
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
        case .announcement: BondTheme.burntOrange
        case .studyGroup: BondTheme.ink
        case .support: BondTheme.violet
        }
    }
}

private struct NotificationConversationRoute: Identifiable {
    let id: UUID
}
