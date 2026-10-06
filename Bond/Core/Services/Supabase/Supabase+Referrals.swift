import Foundation
import Supabase

extension SupabaseProductService: Referring {
    func inviterExists(_ username: String) async throws -> Bool {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        return try await client.rpc("inviter_exists", params: UsernameParams(candidate: username)).execute().value
    }

    func setMyInviter(_ username: String) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("set_my_inviter", params: InviterParams(inviterUsername: username)).execute()
    }

    func fetchReferralSummary() async throws -> ReferralSummary {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ReferralSummaryRow] = try await client.rpc("my_referral_summary").execute().value
        guard let row = rows.first else { return ReferralSummary() }
        return ReferralSummary(joined: row.joined, verified: row.verified)
    }
}

private struct InviterParams: Encodable {
    let inviterUsername: String
    enum CodingKeys: String, CodingKey { case inviterUsername = "inviter_username" }
}

private struct ReferralSummaryRow: Decodable {
    let joined: Int
    let verified: Int
}
