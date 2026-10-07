import SwiftUI

// MARK: - AppState+Referrals
extension AppState {
    /// Kayıt ekranında yazarken: bu kullanıcı adında bir hesap var mı.
    func inviterExists(_ username: String) async throws -> Bool {
        guard let davet = service as? any Referring else { return false }
        return try await davet.inviterExists(username)
    }

    /// Kayıt bitince, sonra her oturum açılışında (bekleyen varsa). Davet eden
    /// bulunamazsa kayıt durmuyor; kısa bir uyarı. Diğer retler (zaten yazılmış,
    /// süresi geçmiş) sessiz. Bağlantı koptuysa yazılan ad cihazda kalır ve bir
    /// sonraki açılışta yeniden denenir; sunucu kayıttan sonra 14 gün kabul ediyor.
    func applyInviterIfNeeded() async {
        let anahtar = SessionKey.account("pendingInviter", userID: currentUserID)
        let yazilan = Username.normalize(inviterUsername)
        inviterUsername = ""
        if !yazilan.isEmpty { defaults.set(yazilan, forKey: anahtar) }
        guard let ad = defaults.string(forKey: anahtar), !ad.isEmpty,
              let davet = service as? any Referring else { return }
        do {
            try await davet.setMyInviter(ad)
            defaults.removeObject(forKey: anahtar)
        } catch {
            guard !isCancellation(error), !isNetworkFailure(error) else { return }
            defaults.removeObject(forKey: anahtar)
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
