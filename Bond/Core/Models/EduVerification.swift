import Foundation

/// Öğrenci e-postası doğrulama durumu. Sunucudaki profil satırı + Auth
/// kullanıcısındaki bekleyen adres (bağlantı gönderildi, henüz tıklanmadı).
struct EduVerificationStatus: Equatable, Sendable {
    var email: String?
    var verifiedAt: Date?
    var exempt: Bool
    /// `auth.users.email_change`: bağlantı gönderildi, onay bekliyor.
    var pendingEmail: String?

    static let unknown = EduVerificationStatus(email: nil, verifiedAt: nil, exempt: false, pendingEmail: nil)

    var isVerified: Bool { verifiedAt != nil }
    var isPending: Bool { !isVerified && pendingEmail != nil }
    /// Kartın görüneceği durum: muaf değil ve henüz doğrulanmamış.
    var needsAttention: Bool { !exempt && !isVerified }
}

enum EduEmailCheck {
    /// Adres izinli bir alan adında mı (`x@yalova.edu.tr`, `x@ogrenci.yalova.edu.tr`)?
    /// Sunucudaki `is_edu_email` ile aynı kural; istemcide anında geri bildirim için.
    static func isAllowed(_ address: String, domains: [String]) -> Bool {
        let parts = address.lowercased().split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let host = String(parts[1])
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func looksLikeEmail(_ address: String) -> Bool {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasSuffix(".")
    }
}
