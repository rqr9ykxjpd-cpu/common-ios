import Foundation
import Supabase

/// Kulüp etkinlikleri; yetki sunucuda (`20261016010000_club_events.sql`).
extension SupabaseProductService: ClubEventsManaging {
    func fetchClubEvents(_ clubID: UUID) async throws -> [ClubEvent] {
        guard currentUserID != nil else { return [] }
        let rows: [ClubEventRow] = try await client
            .rpc("get_club_events", params: ClubIDParams(clubID: clubID))
            .execute().value
        let fotolar = await signedURLs(bucket: "profile-photos", paths: rows.flatMap(\.attendeeAvatars))
        return rows.map { row in
            ClubEvent(id: row.id, clubID: clubID, title: row.title, details: row.details,
                      startsAt: row.startsAt, placeID: row.placeID, placeName: row.placeName,
                      placeNote: row.placeNote, attendeeCount: row.attendeeCount, going: row.going,
                      attendeeAvatars: row.attendeeAvatars.compactMap { fotolar[$0] })
        }
    }

    func fetchEventAttendees(_ eventID: UUID) async throws -> [StudentProfile] {
        let rows: [SupabaseProfileRow] = try await client
            .rpc("get_club_event_attendees", params: ClubEventIDParams(eventID: eventID))
            .execute().value
        let fotolar = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { $0.studentProfile(avatarURL: $0.avatarPath.flatMap { fotolar[$0] }) }
    }

    func setEventAttendance(_ eventID: UUID, going: Bool) async throws -> Int {
        try await client
            .rpc("set_club_event_attendance", params: ClubEventAttendanceParams(eventID: eventID, going: going))
            .execute().value
    }

    func saveClubEvent(_ draft: ClubEventDraft) async throws -> UUID {
        try await client
            .rpc("save_club_event", params: SaveClubEventParams(draft))
            .execute().value
    }

    func cancelClubEvent(_ eventID: UUID) async throws {
        try await client
            .rpc("cancel_club_event", params: ClubEventIDParams(eventID: eventID))
            .execute()
    }

    func fetchMyUpcomingEvents() async throws -> [MyClubEvent] {
        guard currentUserID != nil else { return [] }
        let rows: [MyClubEventRow] = try await client.rpc("get_my_club_events").execute().value
        return rows.map {
            MyClubEvent(id: $0.id, clubID: $0.clubID, clubName: $0.clubName, title: $0.title,
                        startsAt: $0.startsAt, placeLabel: ClubEvent.placeLabel(name: $0.placeName, note: $0.placeNote))
        }
    }
}

private struct ClubEventRow: Decodable {
    let id: UUID
    let title: String
    let details: String
    let startsAt: Date
    let placeID: UUID?
    let placeName: String?
    let placeNote: String
    let attendeeCount: Int
    let going: Bool
    let attendeeAvatars: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, details, going
        case startsAt = "starts_at"
        case placeID = "place_id"
        case placeName = "place_name"
        case placeNote = "place_note"
        case attendeeCount = "attendee_count"
        case attendeeAvatars = "attendee_avatars"
    }
}

private struct MyClubEventRow: Decodable {
    let id: UUID
    let clubID: UUID
    let clubName: String
    let title: String
    let startsAt: Date
    let placeName: String?
    let placeNote: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case clubID = "club_id"
        case clubName = "club_name"
        case startsAt = "starts_at"
        case placeName = "place_name"
        case placeNote = "place_note"
    }
}

private struct ClubEventIDParams: Encodable {
    let eventID: UUID
    enum CodingKeys: String, CodingKey { case eventID = "event_id" }
}

private struct ClubEventAttendanceParams: Encodable {
    let eventID: UUID
    let going: Bool
    enum CodingKeys: String, CodingKey {
        case going
        case eventID = "event_id"
    }
}

/// Boş alanlar da açıkça gönderiliyor: nil iken anahtar düşerse sunucu
/// fonksiyonu bulamıyor (bkz. `set_my_card_theme` dersi).
private struct SaveClubEventParams: Encodable {
    let draft: ClubEventDraft
    init(_ draft: ClubEventDraft) { self.draft = draft }

    enum CodingKeys: String, CodingKey {
        case title, details
        case eventID = "event_id"
        case clubID = "club_id"
        case startsAt = "starts_at"
        case placeID = "place_id"
        case placeNote = "place_note"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(draft.id, forKey: .eventID)
        try c.encode(draft.clubID, forKey: .clubID)
        try c.encode(draft.title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .title)
        try c.encode(draft.details.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .details)
        try c.encode(ISO8601DateFormatter().string(from: draft.startsAt), forKey: .startsAt)
        try c.encode(draft.placeID, forKey: .placeID)
        try c.encode(draft.placeNote.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .placeNote)
    }
}
