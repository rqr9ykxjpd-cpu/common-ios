import Foundation

/// Sohbeti yalnızca kendinden temizleme. Karşı tarafın geçmişi durur.
protocol ConversationClearing: Sendable {
    func clearConversation(_ matchID: UUID) async throws
}
