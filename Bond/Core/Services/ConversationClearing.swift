import Foundation

/// Sohbeti yalnızca kendinden temizleme. Karşı tarafın geçmişi durur.
protocol ConversationClearing: Sendable {
    func clearConversation(_ matchID: UUID) async throws
    /// Temizlediğin sohbetler: temizlikten sonra mesaj yoksa listede gösterilmez.
    func fetchClearedConversationIDs() async -> Set<UUID>
}
