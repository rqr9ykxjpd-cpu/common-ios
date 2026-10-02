import Foundation
import Supabase

extension SupabaseProductService: ConversationClearing {
    func clearConversation(_ matchID: UUID) async throws {
        try await client.rpc("clear_conversation", params: ClearConversationParams(targetMatch: matchID)).execute()
    }

    func fetchClearedConversationIDs() async -> Set<UUID> {
        Set(await conversationClearDates().keys)
    }

    /// Temizlenmiş sohbetlerde damgadan önceki mesajlar gösterilmez.
    func conversationClearDates() async -> [UUID: Date] {
        guard let userID = currentUserID else { return [:] }
        let rows: [ConversationClearRow] = (try? await client
            .from("conversation_clears")
            .select("match_id,cleared_at")
            .eq("user_id", value: userID)
            .execute()
            .value) ?? []
        return Dictionary(rows.map { ($0.matchID, $0.clearedAt) }, uniquingKeysWith: { a, _ in a })
    }
}

private struct ClearConversationParams: Encodable {
    let targetMatch: UUID
    enum CodingKeys: String, CodingKey { case targetMatch = "target_match" }
}

private struct ConversationClearRow: Decodable {
    let matchID: UUID
    let clearedAt: Date
    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case clearedAt = "cleared_at"
    }
}
