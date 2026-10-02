#if DEBUG
import Foundation

extension SampleProductService: NotificationDeleting {
    func deleteNotification(_ notificationID: UUID) async throws {
        await store.removeNotification(notificationID)
    }

    func deleteAllNotifications() async throws {
        await store.removeAllNotifications()
    }
}

extension SampleStore {
    func removeNotification(_ id: UUID) { notifications.removeAll { $0.id == id } }
    func removeAllNotifications() { notifications = [] }
}
#endif
