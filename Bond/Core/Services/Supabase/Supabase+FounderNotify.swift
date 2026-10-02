import Foundation
import Supabase

extension SupabaseProductService: FounderNotifying {
    func notifyUser(_ userID: UUID, title: String, body: String) async throws {
        try await client
            .rpc("founder_notify_user", params: FounderNotifyParams(target: userID, title: title, body: body))
            .execute()
    }
}

private struct FounderNotifyParams: Encodable {
    let target: UUID
    let title: String
    let body: String
}
