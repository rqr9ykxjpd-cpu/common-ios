import SwiftUI

// MARK: - AppState+ClubAccounts
extension AppState {
    /// Kulüp hesabı bağlamak Common hesabının işi (sunucu kurucuya da izin veriyor).
    var canMakeClubAccounts: Bool { currentUserID == OfficialAccount.id }

    func clubAccountClub(of userID: UUID) async throws -> UUID? {
        guard let masa = service as? any ClubAccountManaging else { return nil }
        return try await masa.clubAccountClub(of: userID)
    }

    /// Bağlar, sonra kulüp listesini tazeler (yönetici ve üye sayısı değişti).
    func makeClubAccount(_ userID: UUID, clubID: UUID) async throws -> String {
        guard let masa = service as? any ClubAccountManaging else { throw BackendServiceError.missingSession }
        let ad = try await masa.makeClubAccount(userID, clubID: clubID)
        await loadClubs(silently: true)
        return ad
    }

    func removeClubAccount(_ userID: UUID) async throws {
        guard let masa = service as? any ClubAccountManaging else { throw BackendServiceError.missingSession }
        try await masa.removeClubAccount(userID)
        await loadClubs(silently: true)
    }
}
