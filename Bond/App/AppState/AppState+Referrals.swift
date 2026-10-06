import SwiftUI

// MARK: - AppState+Referrals
extension AppState {
    /// Kayıt ekranında yazarken: bu kullanıcı adında bir hesap var mı.
    func inviterExists(_ username: String) async throws -> Bool {
        guard let davet = service as? any Referring else { return false }
        return try await davet.inviterExists(username)
    }

    /// Kayıt bitince bir kez. Davet eden bulunamazsa kayıt durmuyor; kısa bir
    /// uyarı. Diğer retler (zaten yazılmış, süresi geçmiş) sessiz.
    func applyInviterIfNeeded() async {
        let ad = Username.normalize(inviterUsername)
        inviterUsername = ""
        guard !ad.isEmpty, let davet = service as? any Referring else { return }
        do {
            try await davet.setMyInviter(ad)
        } catch {
            guard !isCancellation(error) else { return }
            if (String(describing: error) + error.localizedDescription).contains("REFERRAL_NOT_FOUND") {
                show(L10n.Referral.notSaved(ad))
            }
        }
    }

    /// Sessiz: sayılar gelmezse ekran sıfır göstermiyor, boş kalıyor.
    func loadReferralSummary() async {
        guard let davet = service as? any Referring else { return }
        if let ozet = try? await davet.fetchReferralSummary() {
            referralSummary = ozet
        }
    }
}
