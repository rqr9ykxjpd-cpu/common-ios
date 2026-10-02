#if DEBUG
import Foundation

/// Örnek mod: "00000000" yanlış kod, diğer 8 haneliler doğru.
extension SampleProductService: EduCodeVerifying {
    func verifyEduCode(email: String, code: String) async throws -> Bool {
        if code == "00000000" { throw SampleEduCodeError.invalid }
        return await store.completeEduNow()
    }
}

enum SampleEduCodeError: Error, LocalizedError {
    case invalid
    var errorDescription: String? { "Token has expired or is invalid" }
}

extension SampleStore {
    func completeEduNow() -> Bool {
        guard let adres = eduStatus.pendingEmail else { return eduStatus.isVerified }
        eduStatus = EduVerificationStatus(email: adres, verifiedAt: .now, exempt: eduStatus.exempt, pendingEmail: nil)
        return true
    }
}
#endif
