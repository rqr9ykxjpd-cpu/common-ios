import Foundation
import Supabase

extension SupabaseProductService {
    func fetchNotifications() async throws -> [BackendNotification] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [NotificationRow] = try await client
            .from("notifications")
            .select("id,kind,title,body,actor_id,match_id,is_read,created_at,actor:profiles!notifications_actor_id_fkey(name,avatar_path)")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.actor?.avatarPath })
        return rows.map { row in
            BackendNotification(
                id: row.id,
                kind: row.appKind,
                title: row.title,
                body: row.body,
                actorID: row.actorID,
                actorName: row.actor?.name,
                actorAvatarURL: row.actor?.avatarPath.flatMap { avatarURLs[$0] },
                matchID: row.matchID,
                isRead: row.isRead,
                createdAt: row.createdAt
            )
        }
    }

    func markNotificationRead(_ notificationID: UUID) async throws {
        try await client.from("notifications")
            .update(NotificationReadUpdate(isRead: true), returning: .minimal)
            .eq("id", value: notificationID)
            .execute()
    }

    func markAllNotificationsRead() async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("notifications")
            .update(NotificationReadUpdate(isRead: true), returning: .minimal)
            .eq("user_id", value: userID)
            .eq("is_read", value: false)
            .execute()
    }

    func registerDeviceToken(_ token: String) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("device_tokens")
            .upsert(DeviceTokenUpsert(userID: userID, token: token, platform: "ios"), returning: .minimal)
            .execute()
    }
}
