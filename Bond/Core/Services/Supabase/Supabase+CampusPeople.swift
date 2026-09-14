import Foundation
import Supabase

extension SupabaseProductService {
    func fetchIntroductionRequests() async throws -> [StudentProfile] {
        let rows: [SupabaseProfileRow] = try await client
            .rpc("get_introduction_requests").execute().value
        let urls = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { $0.studentProfile(avatarURL: $0.avatarPath.flatMap { urls[$0] }) }
    }

    func fetchCampusPeople(offset: Int, limit: Int) async throws -> [StudentProfile] {
        let rows: [CampusPersonRow] = try await client
            .rpc(
                "get_campus_people",
                params: CampusPeoplePageParams(pageLimit: limit, pageOffset: offset)
            )
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { row in
            let age = max(18, Calendar.current.dateComponents([.year], from: row.birthDate, to: .now).year ?? 18)
            return StudentProfile(
                id: row.id,
                name: row.name,
                age: age,
                university: row.university,
                department: row.department,
                year: row.academicYear,
                bio: row.bio,
                interests: row.interests,
                imageURL: row.avatarPath.flatMap { avatarURLs[$0] },
                isVerified: row.isVerified,
                badge: row.badge ?? .none,
                visiblePlaceID: row.visiblePlaceID
            )
        }
    }

    /// Sola kaydırma: sessizce kaydedilir, kimseye görünmez (kurucu hariç).
    func recordLeftSwipe(on profileID: UUID) async throws {
        try await client.rpc("swipe_left_on_profile", params: RightSwipeParams(subject: profileID)).execute()
    }

    /// Kurucu: kartımı kim sağa/sola kaydırdı.
    func fetchProfileSwipers() async throws -> [ProfileSwiper] {
        let rows: [ProfileSwiperRow] = try await client.rpc("who_swiped_me").execute().value
        let avatars = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map {
            ProfileSwiper(id: $0.id, name: $0.name, avatarURL: $0.avatarPath.flatMap { avatars[$0] },
                          swipedRight: $0.direction == "right", swipedAt: $0.swipedAt, isMatched: $0.isMatched)
        }
    }

    func sendRightSwipe(to profileID: UUID) async throws -> RightSwipeOutcome {
        let rows: [RightSwipeRow] = try await client
            .rpc("swipe_right_on_profile", params: RightSwipeParams(subject: profileID))
            .execute()
            .value
        let row = rows.first
        return RightSwipeOutcome(matched: row?.matched == true, matchID: row?.matchID)
    }
}
