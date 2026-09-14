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

    /// Kurucu: "Veriler". Sunucu rozeti kontrol eder.
    func fetchFounderStats() async throws -> FounderStats {
        try await client.rpc("get_founder_stats").execute().value
    }

    func sendFounderBroadcast(title: String, body: String, testOnly: Bool) async throws -> Int {
        try await client.rpc("founder_broadcast", params: BroadcastParams(title: title, body: body, testOnly: testOnly)).execute().value
    }

    func fetchFounderUsers(search: String) async throws -> [FounderUser] {
        let rows: [FounderUserRow] = try await client
            .rpc("get_founder_users", params: FounderUsersParams(search: search, lim: 100))
            .execute().value
        let avatars = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map {
            FounderUser(id: $0.id, name: $0.name, department: $0.department, academicYear: $0.academicYear,
                        avatarURL: $0.avatarPath.flatMap { avatars[$0] },
                        badge: ProfileBadge(rawValue: $0.badge) ?? .none,
                        isVerified: $0.isVerified, isActive: $0.isActive,
                        plan: SubscriptionTier(serverValue: $0.plan),
                        createdAt: $0.createdAt, lastActiveAt: $0.lastActiveAt)
        }
    }

    func founderGrantPlan(_ userID: UUID, plan: SubscriptionTier, days: Int?) async throws -> SubscriptionTier {
        let yeni: String = try await client
            .rpc("founder_grant_plan", params: FounderGrantParams(target: userID, newPlan: plan.serverValue, days: days))
            .execute().value
        return SubscriptionTier(serverValue: yeni)
    }

    func founderSetModerator(_ userID: UUID, enabled: Bool) async throws -> ProfileBadge {
        let yeni: String = try await client
            .rpc("founder_set_moderator", params: FounderModeratorParams(target: userID, enabled: enabled))
            .execute().value
        return ProfileBadge(rawValue: yeni) ?? .none
    }

    func founderSetActive(_ userID: UUID, active: Bool) async throws -> Bool {
        try await client.rpc("founder_set_active", params: FounderActiveParams(target: userID, active: active)).execute().value
    }

    func fetchFounderDaily(days: Int) async throws -> [FounderDay] {
        let rows: [FounderDayRow] = try await client
            .rpc("get_founder_daily", params: FounderDaysParams(days: days)).execute().value
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return rows.compactMap { r in
            guard let d = f.date(from: r.day) else { return nil }
            return FounderDay(day: d, newUsers: r.newUsers, activeUsers: r.activeUsers, posts: r.posts, matches: r.matches ?? 0)
        }
    }

    func fetchFounderAnnouncements() async throws -> [FounderAnnouncement] {
        let rows: [FounderAnnouncementRow] = try await client
            .rpc("get_founder_announcements", params: FounderAnnouncementsParams(lim: 3)).execute().value
        return rows.map { FounderAnnouncement(title: $0.title, body: $0.body, sentAt: $0.sentAt, recipients: $0.recipients) }
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
