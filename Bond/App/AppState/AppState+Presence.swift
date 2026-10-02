import UIKit

// MARK: - AppState+Presence
extension AppState {
    /// Uygulama açıkken dakikada bir "buradayım" (`touch_last_active` → `online_at`).
    /// Kurucunun Kullanıcılar listesindeki yeşil nokta buna bakıyor; diğer
    /// öğrenciler yalnızca kaba etiketi ("Yakın zamanda aktif") görüyor. Arka plana
    /// geçince "ayrıldım" gider; telefon kapanırsa sunucu 3 dakikada düşürür.
    func startPresenceHeartbeat() {
        presenceTask?.cancel()
        watchBackgroundForPresence()
        presenceTask = Task { [weak self] in
            while !Task.isCancelled {
                // Dakikada bir: sunucu 3 dakikadır ses gelmeyeni çevrimdışı sayıyor.
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { return }
                guard self.route == .app, UIApplication.shared.applicationState == .active else { continue }
                do {
                    try await self.service.touchLastActive()
                } catch {
                    // Bu nabız uygulama açıkken düzenli giden tek istek: oturum
                    // düştüyse ilk burada fark edilir.
                    self.verifySessionIfAuthError(error)
                }
            }
        }
    }

    func stopPresenceHeartbeat() {
        presenceTask?.cancel()
        presenceTask = nil
    }

    /// Uygulama arka plana geçince "ayrıldım": panelde yeşil nokta hemen söner.
    /// Dönüşte `refreshAfterForeground` zaten "buradayım" diyor.
    private func watchBackgroundForPresence() {
        guard backgroundPresenceObserver == nil else { return }
        backgroundPresenceObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.reportOffline() }
            }
        }
    }

    /// iOS uygulamayı askıya almadan istek bitsin diye kısa arka plan süresi istenir.
    func reportOffline() async {
        guard route == .app, let bildirici = service as? any PresenceReporting else { return }
        let gorev = BackgroundTaskToken.begin(name: "cevrimdisi")
        await bildirici.markOffline()
        gorev.end()
    }
}

/// `beginBackgroundTask` kimliğini süre dolunca da kapatabilmek için kutu.
@MainActor
private final class BackgroundTaskToken {
    private var kimlik: UIBackgroundTaskIdentifier = .invalid

    static func begin(name: String) -> BackgroundTaskToken {
        let token = BackgroundTaskToken()
        token.kimlik = UIApplication.shared.beginBackgroundTask(withName: name) { [weak token] in
            MainActor.assumeIsolated { token?.end() }
        }
        return token
    }

    func end() {
        guard kimlik != .invalid else { return }
        UIApplication.shared.endBackgroundTask(kimlik)
        kimlik = .invalid
    }
}
