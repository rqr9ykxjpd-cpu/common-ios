#if DEBUG
import Foundation

/// Örnek modda kulüp hesabı bu açılış boyunca bellekte tutulur.
extension SampleProductService: ClubAccountManaging {
    func clubAccountClub(of userID: UUID) async throws -> UUID? {
        await SampleClubAccountStore.shared.links[userID]
    }

    func makeClubAccount(_ userID: UUID, clubID: UUID) async throws -> String {
        await SampleClubAccountStore.shared.link(userID, clubID)
        return try await fetchClubs().clubs.first { $0.id == clubID }?.name ?? ""
    }

    func removeClubAccount(_ userID: UUID) async throws {
        await SampleClubAccountStore.shared.unlink(userID)
    }
}

private actor SampleClubAccountStore {
    static let shared = SampleClubAccountStore()
    private(set) var links: [UUID: UUID] = [:]
    func link(_ user: UUID, _ club: UUID) { links[user] = club }
    func unlink(_ user: UUID) { links[user] = nil }
}
#endif
