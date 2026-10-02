import Foundation
import Supabase

extension SupabaseProductService: NotificationDeleting {
    func deleteNotification(_ notificationID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("notifications")
            .delete(returning: .minimal)
            .eq("id", value: notificationID)
            .eq("user_id", value: userID)
            .execute()
    }

    func deleteAllNotifications() async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("notifications")
            .delete(returning: .minimal)
            .eq("user_id", value: userID)
            .execute()
    }
}
