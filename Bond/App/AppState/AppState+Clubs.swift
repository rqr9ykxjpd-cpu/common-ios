import SwiftUI

// MARK: - AppState+Clubs
extension AppState {
    /// Kulübü düzenleyebilir mi: kurucu her kulübü, yönetici kendi kulübünü.
    func canManage(_ clubID: UUID) -> Bool {
        isFounder || managedClubIDs.contains(clubID)
    }

    /// Logo ve iletişim. Sessiz: gelmezse kulüpler simgeyle görünür.
    func loadClubExtras() async {
        guard let masa = service as? any ClubManaging else { return }
        do { clubExtras = try await masa.fetchClubExtras() }
        catch { guard !isCancellation(error) else { return } }
    }

    func loadManagedClubs() async {
        guard let masa = service as? any ClubManaging else { return }
        do { managedClubIDs = try await masa.fetchManagedClubIDs() }
        catch { guard !isCancellation(error) else { return } }
    }

    func fetchAdminClubs() async throws -> [ClubAdminEntry] {
        guard let masa = service as? any ClubManaging else { return [] }
        return try await masa.fetchAdminClubs()
    }

    /// Kaydeder, sonra listeyi ve logoları tazeler ki her ekranda hemen görünsün.
    func saveClub(_ draft: ClubDraft) async throws -> UUID {
        guard let masa = service as? any ClubManaging else { throw BackendServiceError.missingSession }
        let id = try await masa.saveClub(draft)
        await loadClubs(silently: true)
        await loadClubExtras()
        return id
    }

    func uploadClubLogo(_ clubID: UUID, imageData: Data) async throws -> URL? {
        guard let masa = service as? any ClubManaging else { return nil }
        guard let hazir = await ImageCompression.prepareForUploadInBackground(imageData) else { return nil }
        let url = try await masa.uploadClubLogo(clubID, imageData: hazir)
        await loadClubExtras()
        return url
    }

    func fetchClubPeople(_ clubID: UUID) async throws -> [ClubPerson] {
        guard let masa = service as? any ClubManaging else { return [] }
        return try await masa.fetchClubPeople(clubID)
    }

    func setClubManager(_ clubID: UUID, userID: UUID, enabled: Bool) async throws -> Bool {
        guard let masa = service as? any ClubManaging else { throw BackendServiceError.missingSession }
        return try await masa.setClubManager(clubID, userID: userID, enabled: enabled)
    }

    func removeClubMember(_ clubID: UUID, userID: UUID) async throws {
        guard let masa = service as? any ClubManaging else { throw BackendServiceError.missingSession }
        try await masa.removeClubMember(clubID, userID: userID)
        await loadClubs(silently: true)
    }
}
