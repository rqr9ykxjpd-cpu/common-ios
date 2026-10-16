import Foundation

/// Hesabın dondurulup dondurulmadığı (kurucu ya da moderatör `is_active`i
/// kapattı). Ayrı protokol: `ProductService`e eklenseydi her uygulamasına
/// boş gövde gerekiyordu.
protocol AccountStateReading: Sendable {
    func isMyAccountFrozen() async throws -> Bool
}
