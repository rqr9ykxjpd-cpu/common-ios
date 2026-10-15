import Foundation

/// Sohbetin ortak görünümü (tema, hızlı tepki). Ayrı protokol: `ProductService`e
/// eklenseydi her uygulamasına (örnek, yapılandırılmamış) boş gövde gerekiyordu.
protocol ChatStyling: Sendable {
    /// Değiştirir ve sohbete düşen bilgi satırını döner; değer zaten buysa nil.
    func setChatStyle(_ change: ChatStyleChange, in matchID: UUID) async throws -> Message?
}
