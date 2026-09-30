import Foundation
import Supabase

extension SupabaseProductService: PeopleSuggesting {
    func fetchSuggestions(limit: Int) async throws -> [PersonSuggestion] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [SuggestionRow] = try await client
            .rpc("get_people_you_may_know", params: SuggestionParams(maxCount: limit))
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.compactMap { row in
            guard let reason = PersonSuggestion.Reason(server: row.reason, detail: row.reasonDetail, count: row.reasonCount) else {
                return nil
            }
            let age = max(18, Calendar.current.dateComponents([.year], from: row.birthDate, to: .now).year ?? 18)
            let profile = StudentProfile(
                id: row.id, name: row.name, age: age, university: row.university,
                department: row.department, year: row.academicYear, bio: row.bio,
                interests: row.interests,
                imageURL: row.avatarPath.flatMap { avatarURLs[$0] },
                isVerified: row.isVerified, badge: row.badge ?? .none
            )
            return PersonSuggestion(profile: profile, reason: reason)
        }
    }

    func dismissSuggestion(_ profileID: UUID) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("dismiss_suggestion", params: DismissSuggestionParams(target: profileID)).execute()
    }
}

private struct SuggestionParams: Encodable {
    let maxCount: Int
    enum CodingKeys: String, CodingKey { case maxCount = "max_count" }
}

private struct DismissSuggestionParams: Encodable {
    let target: UUID
}

private struct SuggestionRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    let badge: ProfileBadge?
    let interests: [String]
    let reason: String
    let reasonDetail: String?
    let reasonCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests, badge, reason
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case reasonDetail = "reason_detail"
        case reasonCount = "reason_count"
    }
}
