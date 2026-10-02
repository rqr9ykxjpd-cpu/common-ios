import Auth
import Foundation
import Supabase

extension SupabaseProductService: EduCodeVerifying {
    /// E-posta değişikliğini kodla onaylar, sonra sunucuya damgalatır
    /// (`sync_edu_verification`, alan adını orada da kontrol ediyor).
    func verifyEduCode(email: String, code: String) async throws -> Bool {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        _ = try await client.auth.verifyOTP(email: email, token: code, type: .emailChange)
        _ = try? await client.auth.refreshSession()
        let oldu: Bool = try await client.rpc("sync_edu_verification").execute().value
        return oldu
    }
}
