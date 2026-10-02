import Foundation

/// Bildirim silme. Sunucu yalnızca kişinin kendi bildirimlerini sildirir
/// ("users delete own notifications" kuralı).
protocol NotificationDeleting: Sendable {
    func deleteNotification(_ notificationID: UUID) async throws
    func deleteAllNotifications() async throws
}
