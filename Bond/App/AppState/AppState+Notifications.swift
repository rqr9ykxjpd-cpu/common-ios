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
            let gelen = try await service.fetchNotifications().map(appNotification(from:))
            // Optimistic okundu işaretleri sunucu yanıtından önce gelebilir;
            // ezilirse zildeki rozet geri geliyormuş gibi görünür.
            notifications = gelen.map { item in
                guard pendingNotificationReadIDs.contains(item.id), !item.isRead else { return item }
                var copy = item
                copy.isRead = true
                return copy
            }
            notificationsError = nil
            syncApplicationBadge()
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
        // Dizi elemanının alanını yerinde değiştirmek Observation'da rozeti
        // her zaman yenilemiyordu; diziyi yeniden atayınca zildeki kırmızı sayı düşüyor.
        var guncel = notifications
        guncel[index].isRead = true
        notifications = guncel
        syncApplicationBadge()
        // Liste açılırken `loadNotifications` yarışı okundu işaretini geri almasın.
        pendingNotificationReadIDs.insert(notificationID)
        Task {
            do {
                try await service.markNotificationRead(notificationID)
                pendingNotificationReadIDs.remove(notificationID)
            } catch {
                pendingNotificationReadIDs.remove(notificationID)
                if let refreshed = notifications.firstIndex(where: { $0.id == notificationID }) {
                    var geri = notifications
                    geri[refreshed].isRead = false
                    notifications = geri
                    syncApplicationBadge()
                }
                showError(error, fallback: L10n.Notification.updateFailed)
            }
        }
    }

    func markAllNotificationsRead() {
        let previous = notifications
        let ids = notifications.filter { !$0.isRead }.map(\.id)
        notifications = notifications.map { item in
            var copy = item
            copy.isRead = true
            return copy
        }
        pendingNotificationReadIDs.formUnion(ids)
        syncApplicationBadge()
        Task {
            do {
                try await service.markAllNotificationsRead()
                pendingNotificationReadIDs.subtract(ids)
            } catch {
                pendingNotificationReadIDs.subtract(ids)
                notifications = previous
                syncApplicationBadge()
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
