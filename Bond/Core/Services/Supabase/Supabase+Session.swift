import Auth
import Foundation
import Supabase

extension SupabaseProductService: SessionChecking {
    /// `auth.session` süresi dolmuşsa yenilemeyi dener. Yenileme anahtarı reddedilirse
    /// SDK oturumu silmiyor ve olay göndermiyor; burada o kodlara bakıp "bitti" diyoruz.
    func checkSession() async -> SessionHealth {
        guard client.auth.currentSession != nil else { return .lost }
        do {
            _ = try await client.auth.session
            return .valid
        } catch let error as AuthError {
            let bitmis: [ErrorCode] = [
                .refreshTokenNotFound, .refreshTokenAlreadyUsed,
                .sessionNotFound, .sessionExpired, .userNotFound,
            ]
            return bitmis.contains(error.errorCode) ? .lost : .unknown
        } catch {
            return .unknown
        }
    }
}
