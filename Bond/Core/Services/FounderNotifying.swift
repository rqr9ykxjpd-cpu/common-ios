import Foundation

/// Kurucu: seçtiği tek kullanıcıya bildirim (push dahil).
protocol FounderNotifying: Sendable {
    func notifyUser(_ userID: UUID, title: String, body: String) async throws
}
