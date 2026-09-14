import Foundation
import Supabase

extension SupabaseProductService {
    func fetchReports() async throws -> [ModerationReport] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ReportRow] = try await client
            .from("reports")
            .select("""
            id,reason,details,created_at,handled_at,resolution,target_kind,target_id,content_text,content_media_path,content_media_bucket,\
            reporter:profiles!reports_reporter_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            reported:profiles!reports_reported_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified,is_active)
            """)
            .order("created_at", ascending: false)
            .limit(200)
            .execute()
            .value
        let paths = rows.flatMap { [$0.reporter?.avatarPath, $0.reported?.avatarPath].compactMap { $0 } }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: paths)
        var mediaURLs: [String: URL] = [:]
        for bucket in ["post-media", "story-media"] {
            let mediaPaths = rows.filter { $0.contentMediaBucket == bucket }.compactMap(\.contentMediaPath)
            guard !mediaPaths.isEmpty else { continue }
            // Use short-lived remote URLs rather than the general image cache:
            // reported private media should not be copied into a persistent cache.
            let signed: [SignedURLResult] = (try? await client.storage.from(bucket)
                .createSignedURLs(paths: Array(Set(mediaPaths)), expiresIn: 300)) ?? []
            for result in signed {
                if let url = result.signedURL {
                    mediaURLs["\(bucket)/\(result.path)"] = Self.usableSignedURL(url)
                }
            }
        }
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
                reportedActive: reported.isActive ?? true,
                target: row.targetKind.flatMap { kind in row.targetID.map { ReportTarget(kind: kind, id: $0) } },
                contentText: row.contentText,
                contentMediaURL: row.contentMediaBucket.flatMap { bucket in
                    row.contentMediaPath.flatMap { mediaURLs["\(bucket)/\($0)"] }
                }
            )
        }
    }

    func resolveReport(_ reportID: UUID, resolution: String) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        // Server authorizes and performs the action before closing the report,
        // in one transaction. A failed removal must never appear as resolved.
        try await client.rpc("resolve_content_report", params: ResolveReportParams(
            reportID: reportID, resolution: resolution
        )).execute()
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

}
