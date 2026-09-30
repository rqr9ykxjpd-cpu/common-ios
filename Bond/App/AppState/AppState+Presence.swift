import UIKit

// MARK: - AppState+Presence
extension AppState {
    /// Uygulama açıkken "son aktif" zamanı 2,5 dakikada bir tazelenir. Kurucunun
    /// Kullanıcılar listesindeki yeşil nokta buna bakıyor; diğer öğrenciler yine
    /// yalnızca kaba etiketi ("Yakın zamanda aktif") görüyor. Sunucu 5 dakikadan
    /// sık yazmıyor (`touch_last_active`); arka planda iOS görevi askıya alır.
    func startPresenceHeartbeat() {
        presenceTask?.cancel()
        presenceTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(150))
                guard !Task.isCancelled, let self else { return }
                guard self.route == .app, UIApplication.shared.applicationState == .active else { continue }
                try? await self.service.touchLastActive()
            }
        }
    }

    func stopPresenceHeartbeat() {
        presenceTask?.cancel()
        presenceTask = nil
    }
}
