#if DEBUG
import Foundation

/// Örnek modda davet: örnek kişilerin adları kullanıcı adı yerine geçiyor
/// ("duru", "arda"). Sayılar sabit; ekran dolu görünsün.
extension SampleProductService: Referring {
    func inviterExists(_ username: String) async throws -> Bool {
        let aday = Username.normalize(username)
        return SampleData.profiles.contains { Username.normalize($0.name) == aday }
    }

    func setMyInviter(_ username: String) async throws {
        guard try await inviterExists(username) else { throw SampleReferralError.notFound }
    }

    func fetchReferralSummary() async throws -> ReferralSummary {
        ReferralSummary(joined: 3, verified: 2)
    }
}

/// Sunucunun yükselttiği hatayla aynı metin; istemci onu arıyor.
private enum SampleReferralError: Error, CustomStringConvertible {
    case notFound
    var description: String { "REFERRAL_NOT_FOUND" }
}
#endif
