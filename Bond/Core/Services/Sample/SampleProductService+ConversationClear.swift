#if DEBUG
import Foundation

extension SampleProductService: ConversationClearing {
    func clearConversation(_ matchID: UUID) async throws {
        await store.clearMessages(matchID)
        await SampleClearedStore.shared.add(matchID)
    }

    func fetchClearedConversationIDs() async -> Set<UUID> {
        await SampleClearedStore.shared.ids
    }
}

/// Örnek modda temizlenen sohbetler (öneri satırı da buna bakar).
actor SampleClearedStore {
    static let shared = SampleClearedStore()
    private(set) var ids: Set<UUID> = []
    func add(_ id: UUID) { ids.insert(id) }
}

extension SampleStore {
    func clearMessages(_ matchID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == matchID }) else { return }
        conversations[index].messages = []
        conversations[index].unreadCount = 0
    }
}
#endif
