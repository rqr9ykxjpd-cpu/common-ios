import Foundation
import Network
import Observation

/// Cihazın internete bağlı olup olmadığı.
///
/// Bağlantı yokken her yükleme ayrı ayrı hata veriyordu; kullanıcı art arda
/// uyarı görüyor ama asıl sebebi tek bir yerde görmüyordu. Artık üstte ince
/// bir şerit sebebi söylüyor, bağlantı hatası uyarıları susuyor ve bağlantı
/// dönünce ekranlar kendiliğinden tazeleniyor.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true
#if DEBUG
    /// `-offline`: şeridi ve susturulan uyarıları örnek modda görmek için.
    var debugForceOffline = false
#endif

    var isOffline: Bool {
#if DEBUG
        if debugForceOffline { return true }
#endif
        return !isOnline
    }

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "common.network-monitor"))
    }
}
