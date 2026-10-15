import UIKit
import UserNotifications

extension AppState {
    /// Cihazı APNs'e kaydeder. Sistem izin penceresi yalnızca kullanıcı
    /// Bildirimler ekranındaki açıklamalı eyleme dokunduğunda açılır.
    func startPushRegistration(requestAuthorization: Bool = false) async {
#if DEBUG
        guard !(service is SampleProductService) else { return }
#endif
        guard defaults.bool(forKey: SessionKey.isSignedIn) else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            guard requestAuthorization else { return }
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
        case .denied:
            // İzin sonradan kapatıldıysa sunucudaki jeton da gitsin: kurucunun
            // "bildirimi açık" bilgisi son açılıştaki izni göstersin.
            await unregisterPushToken()
            return
        default:
            break
        }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = PushTokenStore.shared.currentToken {
            await registerPushToken(token)
        }
    }

    /// Bildirim izni, cevap bekleyen bir şey yapılınca (mesaj, bağlantı isteği,
    /// gönderi, yorum, çalışma grubu) önce kısa bir açıklamayla sorulur; sistem
    /// penceresi "Bildirimleri aç"a basınca gelir. Eskiden uygulamaya girer
    /// girmez soruluyordu: neden istendiği belli olmadan reddediliyor, iOS bir
    /// daha sormuyordu (15 Ekim: 30 kişiden 14'ünde açık).
    ///
    /// Açıklama en fazla üç kez ve üç gün arayla gelir; izin kararlıysa hiç.
    func promptForPushIfNeeded(_ reason: PushAskReason = .message) {
        guard pushAsk == nil, !isClubAccount else { return }
        let sayi = defaults.integer(forKey: SessionKey.pushAskCount)
        let son = defaults.object(forKey: SessionKey.pushAskLast) as? Date ?? .distantPast
        guard sayi < 3, Date().timeIntervalSince(son) > 3 * 24 * 3600 else { return }
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .notDetermined else { return }
            // Eylemin kendi animasyonu/tost'u bitsin, kart üstüne binmesin.
            try? await Task.sleep(for: .seconds(1.2))
            guard pushAsk == nil else { return }
            defaults.set(sayi + 1, forKey: SessionKey.pushAskCount)
            defaults.set(Date(), forKey: SessionKey.pushAskLast)
            pushAsk = reason
        }
    }

    /// Açıklama kartında "Bildirimleri aç": sistem penceresi.
    func acceptPushAsk() {
        pushAsk = nil
        defaults.set(true, forKey: SessionKey.pushPrompted)
        Task {
            // Kart kapanırken sistem penceresi üstüne binmesin.
            try? await Task.sleep(for: .seconds(0.4))
            await startPushRegistration(requestAuthorization: true)
            await refreshPushStatus()
        }
    }

    /// Sohbet'teki kart için: izin durumu (açık, kapalı, hiç sorulmadı).
    func refreshPushStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if pushStatus != status { pushStatus = status }
    }

    /// Sohbet'teki "Bildirimler kapalı" kartı: kapalıysa ya da hiç sorulmadıysa,
    /// gizlendikten 14 gün sonra yeniden.
    var showsPushOffCard: Bool {
        guard !isClubAccount, pushStatus == .denied || pushStatus == .notDetermined else { return false }
        let gizlendi = defaults.object(forKey: SessionKey.pushOffHidden) as? Date ?? .distantPast
        return Date().timeIntervalSince(gizlendi) > 14 * 24 * 3600
    }

    func hidePushOffCard() {
        defaults.set(Date(), forKey: SessionKey.pushOffHidden)
        pushOffHiddenTick += 1
    }

    func registerPushToken(_ token: String) async {
        guard defaults.bool(forKey: SessionKey.isSignedIn) else { return }
        do {
            try await service.registerDeviceToken(token)
        } catch {
            #if DEBUG
            print("device token kaydı başarısız:", error)
            #endif
        }
    }

    func unregisterPushToken() async {
        guard let token = PushTokenStore.shared.currentToken else { return }
        try? await service.unregisterDeviceToken(token)
    }

    func syncApplicationBadge() {
        let count = unreadNotificationCount
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(count) }
    }
}
