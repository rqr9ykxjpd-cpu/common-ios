import Foundation
import Supabase

extension SupabaseProductService {
    func fetchReports() async throws -> [ModerationReport] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ReportRow] = try await client
            .from("reports")
            .select("""
            id,reason,details,created_at,handled_at,resolution,\
            reporter:profiles!reports_reporter_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            reported:profiles!reports_reported_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified,is_active)
            """)
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
        let paths = rows.flatMap { [$0.reporter?.avatarPath, $0.reported?.avatarPath].compactMap { $0 } }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: paths)
        return rows.compactMap { row in
            guard let reported = row.reported else { return nil }
            return ModerationReport(
                id: row.id,
                reporter: row.reporter?.studentProfile(avatarURL: row.reporter?.avatarPath.flatMap { urlMap[$0] }),
                reported: reported.studentProfile(avatarURL: reported.avatarPath.flatMap { urlMap[$0] }),
                reason: ReportReason(rawValue: row.reason) ?? .other,
                details: row.details,
                createdAt: row.createdAt,
                handledAt: row.handledAt,
                resolution: row.resolution,
                reportedActive: reported.isActive ?? true
            )
        }
    }

    func resolveReport(_ reportID: UUID, resolution: String) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("reports")
            .update(ReportResolutionUpdate(handledAt: Date(), handledBy: userID, resolution: resolution),
                    returning: .minimal)
            .eq("id", value: reportID)
            .execute()
    }

    /// Silme yetkisi sunucudaki izin kuralında; buradan bakıldığında normal
    /// bir silme isteği. Moderatör değilse sunucu reddediyor.
    func moderatorDeletePost(_ postID: UUID) async throws {
        try await client.from("posts").delete(returning: .minimal).eq("id", value: postID).execute()
    }

    func setAccountActive(_ profileID: UUID, active: Bool) async throws {
        try await client
            .rpc("set_account_active", params: AccountActiveParams(account: profileID, active: active))
            .execute()
    }

    // MARK: - Yanıt istekleri
}
