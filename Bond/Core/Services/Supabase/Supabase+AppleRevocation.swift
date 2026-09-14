import Foundation
import Supabase

extension SupabaseProductService: AppleAccountRevocationService {
    var appleSubject: String? {
        guard let identity = client.auth.currentUser?.identities?.first(where: { $0.provider == "apple" }) else {
            return nil
        }
        if case .string(let subject)? = identity.identityData?["sub"] { return subject }
        return identity.id
    }

    var hasAppleIdentity: Bool {
        let user = client.auth.currentUser
        if user?.identities?.contains(where: { $0.provider == "apple" }) == true { return true }
        // Older locally restored sessions can lack the expanded identities list.
        if case .string("apple")? = user?.appMetadata["provider"] { return true }
        if case .array(let providers)? = user?.appMetadata["providers"] {
            return providers.contains { if case .string("apple") = $0 { return true }; return false }
        }
        return false
    }

    func revokeAppleAuthorization(_ request: AppleAccountRevocationRequest) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        struct Reply: Decodable { let revoked: Bool }
        do {
            let reply: Reply = try await client.functions.invoke(
                "revoke-apple-token",
                options: .init(body: request, timeoutInterval: 30)
            )
            guard reply.revoked else { throw AppleAccountRevocationError.unavailable }
        } catch let error as FunctionsError {
            if case .httpError(let status, _) = error, status == 403 {
                throw AppleAccountRevocationError.accountMismatch
            }
            throw AppleAccountRevocationError.unavailable
        }
    }
}
