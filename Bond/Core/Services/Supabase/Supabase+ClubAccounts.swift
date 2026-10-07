import Foundation
import Supabase

extension SupabaseProductService: ClubAccountManaging {
    func clubAccountClub(of userID: UUID) async throws -> UUID? {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        return try await client.rpc("get_club_account", params: ClubAccountTarget(target: userID)).execute().value
    }

    func makeClubAccount(_ userID: UUID, clubID: UUID) async throws -> String {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        return try await client
            .rpc("make_club_account", params: MakeClubAccountParams(target: userID, club: clubID))
            .execute().value
    }

    func removeClubAccount(_ userID: UUID) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("remove_club_account", params: ClubAccountTarget(target: userID)).execute()
    }
}

private struct ClubAccountTarget: Encodable {
    let target: UUID
}

private struct MakeClubAccountParams: Encodable {
    let target: UUID
    let club: UUID
}
