import Foundation
import Supabase

extension SupabaseProductService {
    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let preferences = DiscoveryPreferencesUpsert(
            userID: userID,
            minAge: filters.minimumAge,
            maxAge: filters.maximumAge,
            academicYears: filters.academicYears.sorted(),
            departments: filters.departments.sorted(),
            requireCommonInterest: filters.requiresCommonInterest,
            campusOnly: filters.campusOnly
        )
        try await client.from("discovery_preferences").upsert(preferences).execute()
        let rows: [DiscoveryCandidateRow] = try await client
            .rpc("get_discovery_candidates", params: DiscoveryPageParams(pageLimit: limit, pageOffset: offset))
            .execute()
            .value
        let paths = rows.flatMap { row in (row.avatarPath.map { [$0] } ?? []) + row.galleryPaths }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: paths)
        #if DEBUG
        print("Bond discovery: \(rows.count) aday, \(paths.count) path, \(urlMap.count) URL")
        #endif
        return rows.map { row in
            row.studentProfile(
                avatarURL: row.avatarPath.flatMap { urlMap[$0] },
                galleryURLs: row.galleryPaths.compactMap { urlMap[$0] }
            )
        }
    }

    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult {
        let rows: [ReactionResultRow] = try await client
            .rpc("react_to_profile", params: ReactionParams(subject: profileID, reaction: liked ? "like" : "pass"))
            .execute()
            .value
        guard let row = rows.first else { return DiscoveryReactionResult(matched: false, matchID: nil) }
        return DiscoveryReactionResult(matched: row.matched, matchID: row.matchID)
    }
    func resetPasses() async throws {
        try await client.rpc("reset_my_passes").execute()
    }
}
