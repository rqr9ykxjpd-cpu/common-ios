import Foundation
import Supabase

/// Doğrulama, kayıt ve bilgi satırı sunucuda (`set_chat_style`,
/// `20261015020000_chat_style.sql`); burası yalnızca çağırıyor.
extension SupabaseProductService: ChatStyling {
    func setChatStyle(_ change: ChatStyleChange, in matchID: UUID) async throws -> Message? {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ChatStyleRow] = try await client
            .rpc("set_chat_style", params: ChatStyleParams(matchID: matchID, kind: change.serverKind,
                                                           value: change.serverValue))
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return Message(id: row.id, body: row.body, isMine: true, sentAt: row.createdAt, style: change)
    }
}

private struct ChatStyleParams: Encodable {
    let matchID: UUID
    let kind: String
    let value: String
    enum CodingKeys: String, CodingKey {
        case kind, value
        case matchID = "match_id"
    }
}

private struct ChatStyleRow: Decodable {
    let id: UUID
    let body: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, body
        case createdAt = "created_at"
    }
}
