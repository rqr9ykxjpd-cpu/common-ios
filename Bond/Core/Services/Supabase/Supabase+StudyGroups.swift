import Foundation
import Supabase

private let studyGroupSelect = """
id,host_id,starts_at,note,capacity,created_at,spot_photo_path,spot_photo_at,\
place:places!study_groups_place_id_fkey(id,name,area),\
host:profiles!study_groups_host_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified,badge),\
members:study_group_members(user_id,joined_at,profile:profiles!study_group_members_user_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified,badge))
"""

extension SupabaseProductService {
    /// Açık gruplar: RLS iptal edileni, süresi dolanı ve dondurulmuş/engelli ev
    /// sahibini zaten süzüyor. En yakın saat üstte.
    func fetchStudyGroups() async throws -> [StudyGroup] {
        let rows: [StudyGroupRow] = try await client
            .from("study_groups")
            .select(studyGroupSelect)
            .order("starts_at", ascending: true)
            .limit(50)
            .execute()
            .value
        return await hydrate(rows)
    }

    func createStudyGroup(placeID: UUID, startsAt: Date, note: String, capacity: Int?) async throws -> StudyGroup {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let row: StudyGroupRow = try await client
            .from("study_groups")
            .insert(StudyGroupInsert(hostID: userID, placeID: placeID, startsAt: startsAt, note: note, capacity: capacity))
            .select(studyGroupSelect)
            .single()
            .execute()
            .value
        guard let group = await hydrate([row]).first else { throw BackendServiceError.missingSession }
        return group
    }

    /// RPC: doğrudan UPDATE, iptal edilen satır okuma politikasından düştüğü için
    /// PostgREST'in RETURNING'li sarmalında RLS'e takılıyordu.
    func cancelStudyGroup(_ groupID: UUID) async throws {
        try await client.rpc("cancel_study_group", params: PostVoterParams(target: groupID)).execute()
    }

    func joinStudyGroup(_ groupID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client
            .from("study_group_members")
            .insert(StudyGroupMemberInsert(groupID: groupID, userID: userID), returning: .minimal)
            .execute()
    }

    func leaveStudyGroup(_ groupID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client
            .from("study_group_members")
            .delete(returning: .minimal)
            .eq("group_id", value: groupID)
            .eq("user_id", value: userID)
            .execute()
    }

    /// Yol: <ev sahibi>/<grup>.jpg — bucket kuralı klasör = kullanıcı. Aynı yola
    /// yeniden yükleme (upsert) fotoğrafı değiştirir.
    func setStudyGroupSpotPhoto(_ groupID: UUID, imageData: Data) async throws -> URL? {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let path = "\(userID.uuidString.lowercased())/\(groupID.uuidString.lowercased()).jpg"
        try await client.storage.from("study-group-photos")
            .upload(path, data: imageData, options: FileOptions(cacheControl: "60", contentType: "image/jpeg", upsert: true))
        try await client.rpc("set_study_group_spot_photo", params: StudyGroupSpotParams(target: groupID, path: path)).execute()
        return await signedURLs(bucket: "study-group-photos", paths: [path])[path]
    }

    private func hydrate(_ rows: [StudyGroupRow]) async -> [StudyGroup] {
        guard !rows.isEmpty else { return [] }
        let userID = currentUserID
        let paths = rows.compactMap { $0.host?.avatarPath }
            + rows.flatMap { $0.members }.compactMap { $0.profile?.avatarPath }
        async let avatarURLs = signedURLs(bucket: "profile-photos", paths: paths)
        // Katılmayanın imzalı URL isteği sunucuda reddedilir; sözlükte yer almaz.
        async let spotURLs = signedURLs(bucket: "study-group-photos", paths: rows.compactMap(\.spotPhotoPath))
        let (urls, spots) = await (avatarURLs, spotURLs)
        return rows.compactMap { row in
            guard let host = row.host, let place = row.place else { return nil }
            let members = row.members
                .sorted { $0.joinedAt < $1.joinedAt }
                .compactMap { member -> StudentProfile? in
                    guard let profile = member.profile else { return nil }
                    return profile.studentProfile(avatarURL: profile.avatarPath.flatMap { urls[$0] })
                }
            return StudyGroup(
                id: row.id,
                host: host.studentProfile(avatarURL: host.avatarPath.flatMap { urls[$0] }),
                place: CampusPlace(id: place.id, name: place.name, area: place.area),
                startsAt: row.startsAt,
                note: row.note,
                capacity: row.capacity,
                members: members,
                createdAt: row.createdAt,
                isMine: row.hostID == userID,
                joined: row.members.contains { $0.userID == userID },
                spotPhotoURL: row.spotPhotoPath.flatMap { spots[$0] },
                spotPhotoAt: row.spotPhotoAt
            )
        }
    }
}
