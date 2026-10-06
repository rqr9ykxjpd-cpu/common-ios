import Foundation
import Supabase

extension SupabaseProductService: PostActionSetting {
    func setPostAction(_ postID: UUID, action: PostAction?) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("set_post_cta", params: PostActionParams(target: postID, action: action?.rawValue)).execute()
    }
}

private struct PostActionParams: Encodable {
    let target: UUID
    let action: String?

    // nil de gönderilsin: parametre eksik olursa sunucu fonksiyonu bulamıyor.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(target, forKey: .target)
        try c.encode(action, forKey: .action)
    }

    enum CodingKeys: String, CodingKey { case target, action }
}
