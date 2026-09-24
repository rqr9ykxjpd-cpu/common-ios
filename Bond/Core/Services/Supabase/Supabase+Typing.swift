import Foundation
import Supabase

extension SupabaseProductService {
    func typingChannel(matchID: UUID) -> (any TypingChannel)? {
        guard let userID = currentUserID else { return nil }
        return SupabaseTypingChannel(client: client, matchID: matchID, userID: userID)
    }
}

/// Supabase Realtime yayını (broadcast). Konu adı sohbetin kimliği: yalnızca iki
/// taraf ve sunucu biliyor, tahmin edilemez. Taşınan tek bilgi "yazıyor";
/// mesaj içeriği asla bu kanaldan geçmez.
final class SupabaseTypingChannel: TypingChannel, @unchecked Sendable {
    let signals: AsyncStream<Void>
    private let channel: RealtimeChannelV2
    private let client: SupabaseClient
    private let userID: String
    private let listener: Task<Void, Never>

    private struct Payload: Codable, Sendable {
        let userID: String
        enum CodingKeys: String, CodingKey { case userID = "user_id" }
    }

    init(client: SupabaseClient, matchID: UUID, userID: UUID) {
        self.client = client
        self.userID = userID.uuidString.lowercased()
        let channel = client.channel("typing-\(matchID.uuidString.lowercased())") { config in
            config.broadcast.receiveOwnBroadcasts = false
        }
        self.channel = channel
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        signals = stream
        let own = self.userID
        let broadcasts = channel.broadcastStream(event: "typing")
        listener = Task {
            do { try await channel.subscribeWithError() } catch {
                continuation.finish()
                return
            }
            for await message in broadcasts {
                // Kendi yayınımız zaten gelmiyor; yine de gönderen kontrolü.
                if case let .object(payload)? = message["payload"],
                   case let .string(sender)? = payload["user_id"], sender == own { continue }
                continuation.yield(())
            }
            continuation.finish()
        }
    }

    func ping() async {
        try? await channel.broadcast(event: "typing", message: Payload(userID: userID))
    }

    func close() async {
        listener.cancel()
        await client.removeChannel(channel)
    }
}
