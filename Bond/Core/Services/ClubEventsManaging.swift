import Foundation

/// Kulüp etkinlikleri. Ayrı protokol: `ProductService`e eklenseydi her
/// uygulamasına boş gövde gerekiyordu. Yetkiyi sunucu uyguluyor
/// (`20261016010000_club_events.sql`).
protocol ClubEventsManaging: Sendable {
    func fetchClubEvents(_ clubID: UUID) async throws -> [ClubEvent]
    func fetchEventAttendees(_ eventID: UUID) async throws -> [StudentProfile]
    /// Güncel katılımcı sayısını döner.
    func setEventAttendance(_ eventID: UUID, going: Bool) async throws -> Int
    func saveClubEvent(_ draft: ClubEventDraft) async throws -> UUID
    func cancelClubEvent(_ eventID: UUID) async throws
    func fetchMyUpcomingEvents() async throws -> [MyClubEvent]
}
