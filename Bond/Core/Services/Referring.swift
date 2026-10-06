import Foundation

/// Davet: kayıtta yazılan davet eden ve ayarlardaki sayılar. Ayrı protokol
/// (bkz. `PeopleSuggesting`). Ödülü sunucu veriyor: davet edilen öğrenci
/// e-postasını doğrulayınca davet edene 1 hafta Plus (`reward_referral`).
protocol Referring: Sendable {
    /// Bu kullanıcı adında açık bir hesap var mı (kendin hariç).
    func inviterExists(_ username: String) async throws -> Bool
    /// Kayıt bitince bir kez. Sunucu yalnızca hesabın ilk 14 gününde kabul ediyor.
    func setMyInviter(_ username: String) async throws
    func fetchReferralSummary() async throws -> ReferralSummary
}

struct ReferralSummary: Equatable, Sendable {
    /// Davetinle katılan.
    var joined = 0
    /// Bunlardan öğrenci e-postasını doğrulayan.
    var verified = 0
}
