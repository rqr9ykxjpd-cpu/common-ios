import SwiftUI

// MARK: - AppState+Session
extension AppState {
    /// Oturum sunucuda bittiyse giriş ekranına al ve nedenini söyle.
    ///
    /// Yenileme anahtarı reddedildiğinde uygulama içeride kalıyordu; istekler
    /// misafir olarak gidip "yetki yok" ile dönüyor, kaydet/paylaş düğmeleri hiçbir
    /// şey yapmıyormuş gibi görünüyordu. Ağ hatasında (`.unknown`) dokunulmuyor.
    func verifySession() async {
        guard defaults.bool(forKey: SessionKey.isSignedIn), !isAccountActionInProgress,
              let denetci = service as? any SessionChecking else { return }
        guard await denetci.checkSession() == .lost else { return }
        // Kontrol sürerken kullanıcı kendisi çıkmış olabilir.
        guard defaults.bool(forKey: SessionKey.isSignedIn), !isAccountActionInProgress else { return }
        await unregisterPushToken()
        try? await service.signOut()
        clearSession(keepAccountData: true)
        showError(L10n.Errors.sessionExpired)
    }

    /// Yetki hatası oturum düşmesinin işareti olabilir; kontrol arka planda.
    func verifySessionIfAuthError(_ error: Error) {
        let metin = (String(describing: error) + " " + error.localizedDescription).lowercased()
        let isaretler = ["permission denied", "42501", "jwt", "refresh token", "session", "unauthorized", "401"]
        guard isaretler.contains(where: metin.contains) else { return }
        Task { await verifySession() }
    }
}
