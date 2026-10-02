#if DEBUG
import Foundation

extension SampleProductService: ConversationClearing {
    func clearConversation(_ matchID: UUID) async throws {
        await store.clearMessages(matchID)
    }
}

extension SampleStore {
    func clearMessages(_ matchID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == matchID }) else { return }
        conversations[index].messages = []
        conversations[index].unreadCount = 0
    }
}
#endif
