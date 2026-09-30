import Foundation

/// Destek talepleri ve kurucunun muafiyet işlemi. Ayrı protokol: `ProductService`e
/// eklenseydi her uygulamasına (örnek, yapılandırılmamış) boş gövde gerekiyordu.
protocol SupportDesk: Sendable {
    func fetchMySupportThreads() async throws -> [SupportThread]
    /// Okuyan tarafın "okundu" zamanını da sunucu günceller.
    func fetchSupportMessages(_ reportID: UUID) async throws -> [SupportMessage]
    /// Yeni durumu döndürür. Destek `resolve` ile çözüldü işaretler (yazı isteğe
    /// bağlı); öğrenci yazınca talep yeniden açılır.
    func sendSupportMessage(_ reportID: UUID, body: String, resolve: Bool) async throws -> SupportThread.Status
    /// Kurucu: hesabı öğrenci doğrulamasından muaf tut ya da muafiyeti kaldır.
    func setEduExempt(_ userID: UUID, exempt: Bool) async throws -> Bool
}
