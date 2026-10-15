#if DEBUG
import Foundation

/// Örnek modda tema ve hızlı tepki: sunucudakiyle aynı kural, bu açılış boyunca kalır.
extension SampleProductService: ChatStyling {
    func setChatStyle(_ change: ChatStyleChange, in matchID: UUID) async throws -> Message? {
        await store.applyChatStyle(change, to: matchID)
    }
}

extension SampleStore {
    func applyChatStyle(_ change: ChatStyleChange, to matchID: UUID) -> Message? {
        guard let index = conversations.firstIndex(where: { $0.id == matchID }) else { return nil }
        switch change {
        case .theme(let tema):
            guard conversations[index].theme != tema else { return nil }
            conversations[index].theme = tema
        case .reaction(let emoji):
            guard conversations[index].quickReaction != emoji else { return nil }
            conversations[index].quickReaction = emoji
        }
        let satir = Message(body: change.note(isMine: true, peerName: ""), isMine: true, sentAt: .now, style: change)
        conversations[index].messages.append(satir)
        conversations[index].updatedAt = .now
        return satir
    }
}
#endif
