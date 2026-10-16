import Foundation

// MARK: - AppState+AccountState
extension AppState {
    /// Hesap dondurulduysa uygulama yerine "Hesabın donduruldu" ekranı.
    /// Açılışta ve öne dönüşte bakılır; okunamazsa (ağ, eski sunucu) durum
    /// değişmez.
    func refreshAccountState() async {
        guard let masa = service as? any AccountStateReading,
              let donmus = try? await masa.isMyAccountFrozen() else { return }
        accountFrozen = donmus
    }
}
