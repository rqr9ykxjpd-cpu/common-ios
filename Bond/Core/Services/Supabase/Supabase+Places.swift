import Foundation
import Supabase

extension SupabaseProductService {
    func fetchPlaces() async throws -> [CampusPlace] {
        let rows: [PlaceRow] = try await client
            .from("places")
            .select("id,name,area")
            .order("name")
            .execute()
            .value
        let places = rows.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) }
        return CampusPlaceOrder.sorted(places)
    }

    func fetchMeetingRequests() async throws -> [MeetingRequest] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [MeetingRequestRow] = try await client
            .from("meeting_requests")
            .select("""
            id,requester_id,recipient_id,place_id,status,created_at,\
            place:places!meeting_requests_place_id_fkey(id,name,area),\
            requester:profiles!meeting_requests_requester_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            recipient:profiles!meeting_requests_recipient_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        // Karşı taraf, isteği kimin gönderdiğine göre değişir: gelen istekte gönderen,
        // giden istekte alıcı gösterilmeli.
        let peerPaths = rows.compactMap { $0.requesterID == userID ? $0.recipient?.avatarPath : $0.requester?.avatarPath }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: peerPaths)
        return rows.compactMap { row in
            let outgoing = row.requesterID == userID
            guard let peer = outgoing ? row.recipient : row.requester, let place = row.place else { return nil }
            return MeetingRequest(
                id: row.id,
                profile: peer.studentProfile(avatarURL: peer.avatarPath.flatMap { urlMap[$0] }),
                place: CampusPlace(id: place.id, name: place.name, area: place.area),
                direction: outgoing ? .outgoing : .incoming,
                status: row.meetingStatus,
                createdAt: row.createdAt
            )
        }
    }

    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("meeting_requests")
            .insert(MeetingRequestInsert(requesterID: userID, recipientID: profileID, placeID: placeID), returning: .minimal)
            .execute()
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws -> UUID? {
        if accept {
            let conversationID: UUID = try await client
                .rpc("accept_meeting_request", params: MeetingRequestAcceptParams(request: requestID))
                .execute()
                .value
            return conversationID
        }

        try await client.from("meeting_requests")
            .update(MeetingRequestStatusUpdate(status: "declined"), returning: .minimal)
            .eq("id", value: requestID)
            .execute()
        return nil
    }

    func touchLastActive() async throws {
        try await client.rpc("touch_last_active").execute()
    }
    func setVisiblePlace(_ placeID: UUID?) async throws {
        try await client.rpc("set_visible_place", params: VisiblePlaceParams(targetPlace: placeID)).execute()
    }

    func fetchPeopleAtPlace(_ placeID: UUID) async throws -> [StudentProfile] {
        let rows: [PlacePersonRow] = try await client
            .rpc("get_people_at_place", params: PlacePeopleParams(targetPlace: placeID))
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { row in
            let age = max(18, Calendar.current.dateComponents([.year], from: row.birthDate, to: .now).year ?? 18)
            return StudentProfile(
                id: row.id, name: row.name, age: age, university: row.university,
                department: row.department, year: row.academicYear, bio: row.bio,
                interests: row.interests,
                imageURL: row.avatarPath.flatMap { avatarURLs[$0] },
                compatibility: 0, isVerified: row.isVerified, badge: row.badge ?? .none,
                relationshipIntent: row.relationshipIntent, activeLabel: row.activeLabel
            )
        }
    }

    func fetchClubs() async throws -> (clubs: [CampusClub], joinedIDs: Set<UUID>) {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [ClubRow] = try await client
            .from("clubs")
            .select("id,name,summary,icon,next_event,accent_hex,place:places!clubs_place_id_fkey(id,name,area),club_members(user_id)")
            .order("name")
            .execute()
            .value
        let clubs = rows.map { row in
            CampusClub(
                id: row.id,
                name: row.name,
                summary: row.summary,
                icon: row.icon,
                memberCount: row.members?.count ?? 0,
                nextEvent: row.nextEvent,
                meetingPlace: row.place.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) },
                accentHex: row.accentHex
            )
        }
        let joined = Set(rows.filter { $0.members?.contains { $0.userID == userID } ?? false }.map(\.id))
        return (clubs, joined)
    }

    func setClubMembership(_ clubID: UUID, joined: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if joined {
            try await client.from("club_members")
                .upsert(ClubMemberInsert(clubID: clubID, userID: userID), returning: .minimal,
                        ignoreDuplicates: true)
                .execute()
        } else {
            try await client.from("club_members")
                .delete(returning: .minimal)
                .eq("club_id", value: clubID)
                .eq("user_id", value: userID)
                .execute()
        }
    }

    func fetchStoryViews(_ storyID: UUID) async throws -> [StoryViewRecord] {
        let rows: [StoryViewRow] = try await client
            .from("story_views")
            .select("viewer_id,view_count,last_viewed_at,viewer:profiles!story_views_viewer_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)")
            .eq("story_id", value: storyID)
            .order("last_viewed_at", ascending: false)
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.viewer?.avatarPath })
        return rows.compactMap { row in
            guard let viewer = row.viewer else { return nil }
            return StoryViewRecord(
                viewer: viewer.studentProfile(avatarURL: viewer.avatarPath.flatMap { avatarURLs[$0] }),
                viewCount: row.viewCount,
                lastViewedAt: row.lastViewedAt
            )
        }
    }
}
