import UIKit
import UserNotifications

extension AppState {
    /// İzin ister ve cihazı APNs'e kaydeder. Karşılama ekranında sorulmaz.
    func startPushRegistration() async {
        guard defaults.bool(forKey: SessionKey.isSignedIn) else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            guard granted else { return }
        case .denied:
            return
        default:
            break
        }
        UIApplication.shared.registerForRemoteNotifications()
        if let token = PushTokenStore.shared.currentToken {
            await registerPushToken(token)
        }
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
