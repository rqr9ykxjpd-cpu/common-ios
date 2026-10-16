import Foundation
import Supabase

extension SupabaseProductService: AccountStateReading {
    /// Kendi satırı her zaman okunabiliyor (`id = auth.uid()`), dondurulmuş olsa da.
    func isMyAccountFrozen() async throws -> Bool {
        guard let userID = currentUserID else { return false }
        let rows: [AccountActiveRow] = try await client
            .from("profiles")
            .select("is_active")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first.map { !$0.isActive } ?? false
    }
}

private struct AccountActiveRow: Decodable {
    let isActive: Bool
    enum CodingKeys: String, CodingKey { case isActive = "is_active" }
}
