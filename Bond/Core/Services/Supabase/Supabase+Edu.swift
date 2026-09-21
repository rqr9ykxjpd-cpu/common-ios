import Foundation
import Supabase

/// Öğrenci e-postası doğrulaması, Supabase Auth'un e-posta değişikliği akışı
/// üzerinden: `updateUser(email)` yeni adrese bağlantı gönderir; tıklanınca
/// `auth.users.email` o adres olur. Sunucudaki `sync_edu_verification()` adresi
/// izinli alan adlarıyla karşılaştırıp profili damgalar.
///
/// Dashboard'da gerekenler: Authentication → Email → "Secure email change" KAPALI
/// (eski adres Apple'ın gizli aktarma adresi olabilir, kullanıcı görmez);
/// URL Configuration → Redirect URLs listesinde `dogrulandi.html` adresi;
/// "Change Email Address" şablonu Common tasarımıyla.
extension SupabaseProductService {
    static let eduVerifiedPage = URL(string: "https://rqr9ykxjpd-cpu.github.io/common-ios/dogrulandi.html")!

    func fetchEduStatus() async throws -> EduVerificationStatus {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [EduStatusRow] = try await client.rpc("get_my_edu_status").execute().value
        let row = rows.first
        let bekleyen = client.auth.currentUser?.newEmail
        return EduVerificationStatus(
            email: row?.eduEmail,
            verifiedAt: row?.eduVerifiedAt,
            exempt: row?.eduExempt ?? false,
            pendingEmail: (bekleyen?.isEmpty == false) ? bekleyen : nil
        )
    }

    func fetchEduDomains() async throws -> [String] {
        let rows: [EduDomainRow] = try await client.from("edu_domains").select("domain").execute().value
        return rows.map(\.domain)
    }

    func requestEduVerification(email: String) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        _ = try await client.auth.update(user: UserAttributes(email: email), redirectTo: Self.eduVerifiedPage)
    }

    /// Bağlantı tıklandıysa oturumdaki kullanıcı bilgisi eskimiş olabilir; önce
    /// yenile, sonra sunucuya damgalat.
    func syncEduVerification() async throws -> Bool {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        _ = try? await client.auth.refreshSession()
        _ = try? await client.auth.user()
        let oldu: Bool = try await client.rpc("sync_edu_verification").execute().value
        return oldu
    }
}

struct EduStatusRow: Decodable {
    let eduEmail: String?
    let eduVerifiedAt: Date?
    let eduExempt: Bool
    enum CodingKeys: String, CodingKey {
        case eduEmail = "edu_email"
        case eduVerifiedAt = "edu_verified_at"
        case eduExempt = "edu_exempt"
    }
}

struct EduDomainRow: Decodable {
    let domain: String
}
