import Foundation
import Supabase

extension SupabaseProductService: MessageDeliveryMarking {
    func markMessagesDelivered() async throws {
        guard currentUserID != nil else { return }
        try await client.rpc("mark_messages_delivered").execute()
    }
}
