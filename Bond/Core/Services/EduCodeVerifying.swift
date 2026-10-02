import Foundation

/// Okul e-postasına gelen 8 haneli kodla doğrulama. Bağlantıya dokunmak
/// gerekmez: Microsoft 365'in "Güvenli Bağlantılar" taraması tek kullanımlık
/// bağlantıyı öğrenciden önce açıp tüketiyordu.
protocol EduCodeVerifying: Sendable {
    /// Kod doğruysa profil damgalanır; dönen değer doğrulandı mı.
    func verifyEduCode(email: String, code: String) async throws -> Bool
}
