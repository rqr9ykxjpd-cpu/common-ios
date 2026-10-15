import SwiftUI

// MARK: - AppState+ChatStyle
extension AppState {
    /// Özelleştirme ekranında seçilen tema: sohbet hemen o renge geçer,
    /// sunucuya ekran kapanınca gider (`saveChatStyle`). Her dokunuşta
    /// gönderilseydi sohbet "temayı … yaptı" satırlarıyla dolardı.
    func previewChatTheme(_ tema: CardTheme, in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        withAnimation(BondTheme.Motion.smooth) { conversations[index].theme = tema }
    }

    func previewQuickReaction(_ emoji: String, in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].quickReaction = emoji
    }

    /// Ekran açıldığındaki hâlden farklı olanları kaydeder. Sunucu reddederse
    /// o değişiklik geri alınır.
    func saveChatStyle(in conversationID: UUID, originalTheme: CardTheme, originalReaction: String) async {
        guard let masa = service as? any ChatStyling,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var degisenler: [ChatStyleChange] = []
        if conversations[index].theme != originalTheme { degisenler.append(.theme(conversations[index].theme)) }
        if conversations[index].quickReaction != originalReaction {
            degisenler.append(.reaction(conversations[index].quickReaction))
        }
        for degisen in degisenler {
            do {
                guard let satir = try await masa.setChatStyle(degisen, in: conversationID) else { continue }
                appendStyleNote(satir, in: conversationID)
            } catch {
                guard !isCancellation(error),
                      let i = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
                withAnimation(BondTheme.Motion.smooth) {
                    switch degisen {
                    case .theme: conversations[i].theme = originalTheme
                    case .reaction: conversations[i].quickReaction = originalReaction
                    }
                }
                showError(error, fallback: L10n.ChatStyle.changeFailed)
            }
        }
    }

    /// Karşı taraf değiştirdi (anlık kanaldan gelen bilgi satırı): görünüm burada da değişir.
    func applyIncomingStyle(_ change: ChatStyleChange, at index: Int) {
        withAnimation(BondTheme.Motion.smooth) {
            switch change {
            case .theme(let tema): conversations[index].theme = tema
            case .reaction(let emoji): conversations[index].quickReaction = emoji
            }
        }
    }

    /// Kendi değişikliğimin satırı. Anlık kanal daha önce getirdiyse ikinci kez eklenmez.
    private func appendStyleNote(_ satir: Message, in conversationID: UUID) {
        guard let i = conversations.firstIndex(where: { $0.id == conversationID }),
              !conversations[i].messages.contains(where: { $0.id == satir.id }) else { return }
        withAnimation(.snappy) { conversations[i].messages.append(satir) }
        conversations[i].updatedAt = satir.sentAt
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }
}
