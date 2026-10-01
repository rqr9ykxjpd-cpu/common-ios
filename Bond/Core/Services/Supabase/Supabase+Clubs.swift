import Foundation
import Supabase

/// Kulüp yönetimi. Yetkiyi sunucudaki fonksiyonlar uyguluyor
/// (`20261002010000_club_management.sql`); burası yalnızca çağırıyor.
extension SupabaseProductService: ClubManaging {
    func fetchClubExtras() async throws -> [UUID: ClubExtras] {
        let rows: [ClubExtrasRow] = try await client
            .from("clubs")
            .select("id,logo_path,instagram,contact_email")
            .execute()
            .value
        var sonuc: [UUID: ClubExtras] = [:]
        for row in rows {
            sonuc[row.id] = ClubExtras(logoURL: clubLogoURL(row.logoPath), instagram: row.instagram, contactEmail: row.contactEmail)
        }
        return sonuc
    }

    func fetchManagedClubIDs() async throws -> Set<UUID> {
        guard currentUserID != nil else { return [] }
        let ids: [UUID] = try await client.rpc("get_my_managed_clubs").execute().value
        return Set(ids)
    }

    func fetchAdminClubs() async throws -> [ClubAdminEntry] {
        let rows: [AdminClubRow] = try await client.rpc("founder_list_clubs").execute().value
        return rows.map { row in
            ClubAdminEntry(
                id: row.id,
                draft: ClubDraft(
                    id: row.id, name: row.name, summary: row.summary, icon: row.icon,
                    nextEvent: row.nextEvent, placeID: row.placeID, accentHex: row.accentHex,
                    instagram: row.instagram ?? "", contactEmail: row.contactEmail ?? "",
                    isActive: row.isActive, logoURL: clubLogoURL(row.logoPath)
                ),
                memberCount: row.memberCount,
                managerCount: row.managerCount
            )
        }
    }

    func saveClub(_ draft: ClubDraft) async throws -> UUID {
        try await client.rpc("save_club", params: SaveClubParams(draft)).execute().value
    }

    func uploadClubLogo(_ clubID: UUID, imageData: Data) async throws -> URL? {
        // Yeni ad: önbellekteki eski logo hemen düşsün.
        let path = "\(clubID.uuidString.lowercased())/logo-\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage.from("club-media")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        try await client.rpc("set_club_logo", params: ClubLogoParams(clubID: clubID, path: path)).execute()
        return clubLogoURL(path)
    }

    func fetchClubPeople(_ clubID: UUID) async throws -> [ClubPerson] {
        let rows: [ClubPersonRow] = try await client
            .rpc("get_club_people", params: ClubIDParams(clubID: clubID))
            .execute().value
        let fotolar = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map {
            ClubPerson(id: $0.id, name: $0.name, username: $0.username,
                       avatarURL: $0.avatarPath.flatMap { fotolar[$0] },
                       isManager: $0.isManager, joinedAt: $0.joinedAt)
        }
    }

    func setClubManager(_ clubID: UUID, userID: UUID, enabled: Bool) async throws -> Bool {
        try await client
            .rpc("founder_set_club_manager", params: ClubManagerParams(clubID: clubID, userID: userID, enabled: enabled))
            .execute().value
    }

    func removeClubMember(_ clubID: UUID, userID: UUID) async throws {
        try await client
            .rpc("club_remove_member", params: ClubMemberParams(clubID: clubID, userID: userID))
            .execute()
    }

    /// Logolar herkese açık kovada; imza gerekmiyor.
    private func clubLogoURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return try? client.storage.from("club-media").getPublicURL(path: path)
    }
}

struct ClubExtrasRow: Decodable {
    let id: UUID
    let logoPath: String?
    let instagram: String?
    let contactEmail: String?
    enum CodingKeys: String, CodingKey {
        case id, instagram
        case logoPath = "logo_path"
        case contactEmail = "contact_email"
    }
}

struct AdminClubRow: Decodable {
    let id: UUID
    let name: String
    let summary: String
    let icon: String
    let nextEvent: String
    let placeID: UUID?
    let accentHex: String
    let isActive: Bool
    let logoPath: String?
    let instagram: String?
    let contactEmail: String?
    let memberCount: Int
    let managerCount: Int
    enum CodingKeys: String, CodingKey {
        case id, name, summary, icon, instagram
        case nextEvent = "next_event"
        case placeID = "place_id"
        case accentHex = "accent_hex"
        case isActive = "is_active"
        case logoPath = "logo_path"
        case contactEmail = "contact_email"
        case memberCount = "member_count"
        case managerCount = "manager_count"
    }
}

struct ClubPersonRow: Decodable {
    let id: UUID
    let name: String
    let username: String?
    let avatarPath: String?
    let isManager: Bool
    let joinedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, name, username
        case avatarPath = "avatar_path"
        case isManager = "is_manager"
        case joinedAt = "joined_at"
    }
}

struct SaveClubParams: Encodable {
    let clubID: UUID?
    let name: String
    let summary: String
    let icon: String
    let nextEvent: String
    let placeID: UUID?
    let accentHex: String
    let instagram: String
    let contactEmail: String
    let isActive: Bool

    init(_ d: ClubDraft) {
        clubID = d.id; name = d.name; summary = d.summary; icon = d.icon; nextEvent = d.nextEvent
        placeID = d.placeID; accentHex = d.accentHex; instagram = d.instagram
        contactEmail = d.contactEmail; isActive = d.isActive
    }

    enum CodingKeys: String, CodingKey {
        case name, summary, icon, instagram
        case clubID = "club_id"
        case nextEvent = "next_event"
        case placeID = "place_id"
        case accentHex = "accent_hex"
        case contactEmail = "contact_email"
        case isActive = "is_active"
    }

    // Sunucu fonksiyonu adlarla eşleşiyor; nil alanlar null olarak gitmeli.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(clubID, forKey: .clubID)
        try c.encode(name, forKey: .name)
        try c.encode(summary, forKey: .summary)
        try c.encode(icon, forKey: .icon)
        try c.encode(nextEvent, forKey: .nextEvent)
        try c.encode(placeID, forKey: .placeID)
        try c.encode(accentHex, forKey: .accentHex)
        try c.encode(instagram, forKey: .instagram)
        try c.encode(contactEmail, forKey: .contactEmail)
        try c.encode(isActive, forKey: .isActive)
    }
}

struct ClubLogoParams: Encodable {
    let clubID: UUID
    let path: String
    enum CodingKeys: String, CodingKey { case path; case clubID = "club_id" }
}

struct ClubIDParams: Encodable {
    let clubID: UUID
    enum CodingKeys: String, CodingKey { case clubID = "club_id" }
}

struct ClubManagerParams: Encodable {
    let clubID: UUID
    let userID: UUID
    let enabled: Bool
    enum CodingKeys: String, CodingKey { case enabled; case clubID = "club_id"; case userID = "user_id" }
}

struct ClubMemberParams: Encodable {
    let clubID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey { case clubID = "club_id"; case userID = "user_id" }
}
