import Foundation

/// "Ayrıldım": uygulama arka plana geçince çevrimiçi göstergesi hemen düşsün.
protocol PresenceReporting: Sendable {
    func markOffline() async
}
