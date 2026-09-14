import UIKit
import UserNotifications

/// APNs jetonunu oturumdan bağımsız tutar: sistem jetonu, giriş tamamlanmadan
/// önce gelebilir. Oturum hazır olunca `AppState` kaydı sunucuya yazar.
@MainActor
final class PushTokenStore {
    static let shared = PushTokenStore()

    private(set) var currentToken: String?
    private weak var appState: AppState?

    func bind(_ appState: AppState) {
        self.appState = appState
        // Yerel "oturum açık" bayrağı, gerçek Supabase oturumu geri yüklenmeden
        // okunursa eski kalabilir. Burada izin istemek bu yüzden giriş ekranını
        // sistem bildirimiyle kapatıyordu. Kayıt; başarılı giriş, geçerli oturum
        // geri yükleme veya onboarding tamamlandıktan sonra başlatılıyor.
        if let currentToken {
            Task { await appState.registerPushToken(currentToken) }
        }
    }

    func didReceive(_ token: String) {
        currentToken = token
        Task { await appState?.registerPushToken(token) }
    }

    func handleNotificationTap() {
        appState?.opensNotifications = true
        Task { await appState?.loadNotifications() }
    }

    func handleForegroundBanner() {
        Task { await appState?.loadNotifications() }
    }
}

final class BondAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        URLCache.shared = URLCache(memoryCapacity: 2 * 1024 * 1024, diskCapacity: 40 * 1024 * 1024, directory: nil)
        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(purgeImageMemory),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        return true
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        purgeImageMemory()
    }

    @objc private func purgeImageMemory() {
        URLCache.shared.removeAllCachedResponses()
        Task { await BondImageLoader.shared.purgeMemory() }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            PushTokenStore.shared.didReceive(token)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
        Task { @MainActor in
            PushTokenStore.shared.handleForegroundBanner()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            PushTokenStore.shared.handleNotificationTap()
        }
        completionHandler()
    }
}
