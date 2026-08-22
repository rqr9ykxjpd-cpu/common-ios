import SwiftUI

// MARK: - AppState+Notifications
extension AppState {
    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    /// Bildirimleri sunucudan yükler. Bu ekran şimdiye kadar yalnızca demo örneklerinden
    /// besleniyordu; gerçek kullanıcı eşleşme veya mesaj aldığında hiçbir şey görmüyordu.
    func loadNotifications() async {
        isLoadingNotifications = true
        defer { isLoadingNotifications = false }
        do {
            notifications = try await service.fetchNotifications().map(appNotification(from:))
            notificationsError = nil
        } catch {
            guard !isCancellation(error) else { return }
            let message = UserFacingError.message(error, fallback: L10n.Notification.loadFailed)
            notificationsError = message
            // Eski içerik hâlâ ekrandaysa yenileme hatasını görünür kıl; ilk yükleme
            // hatasında ise ekran kendi kalıcı retry durumunu gösterir.
            if !notifications.isEmpty { showError(message) }
        }
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }), !notifications[index].isRead else { return }
        notifications[index].isRead = true
        Task {
            do { try await service.markNotificationRead(notificationID) }
            catch {
                if let refreshed = notifications.firstIndex(where: { $0.id == notificationID }) {
                    notifications[refreshed].isRead = false
                }
                showError(error, fallback: L10n.Notification.updateFailed)
            }
        }
    }

    func markAllNotificationsRead() {
        let previous = notifications
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        Task {
            do { try await service.markAllNotificationsRead() }
            catch {
                notifications = previous
                showError(error, fallback: L10n.Notification.bulkFailed)
            }
        }
    }

    func appNotification(from backend: BackendNotification) -> AppNotification {
        let actor = backend.actorID.map { actorID in
            StudentProfile(
                id: actorID,
                name: backend.actorName ?? L10n.Common.someone,
                age: 18,
                university: draft.university,
                department: "",
                year: "",
                bio: "",
                interests: [],
                imageURL: backend.actorAvatarURL,
                compatibility: 0,
                isVerified: true
            )
        }
        return AppNotification(
            id: backend.id,
            kind: backend.kind,
            title: NotificationCopy.title(kind: backend.kind, actorName: actor?.name ?? L10n.Common.someone, serverTitle: backend.title),
            body: NotificationCopy.body(kind: backend.kind, actorName: actor?.name ?? L10n.Common.someone, serverTitle: backend.title, serverBody: backend.body),
            actor: actor,
            conversationID: backend.matchID,
            createdAt: backend.createdAt,
            isRead: backend.isRead
        )
    }
}
