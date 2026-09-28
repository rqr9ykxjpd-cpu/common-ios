import Foundation

/// "Tanıyor olabileceğin kişiler" önerileri. Ayrı protokol: `ProductService`e
/// eklenseydi her uygulamasına (örnek, yapılandırılmamış) boş gövde gerekiyordu.
protocol PeopleSuggesting: Sendable {
    func fetchSuggestions(limit: Int) async throws -> [PersonSuggestion]
    /// × ile kaldırılan kişi bir daha önerilmez. Kimseye bildirilmez.
    func dismissSuggestion(_ profileID: UUID) async throws
}
