import Foundation

/// Kullanıcının akışta hangi gönderiyi kaç kez gördüğü — cihazda, kişiye özel.
/// Popüler sırası buna bakar: görülen gönderi bir sonraki açılışta aşağı iner,
/// aynı gönderi tepeyi meşgul etmez. Sunucuya gitmez; kaybolsa bir şey olmaz.
@MainActor
enum FeedSeenTracker {
    private static let key = "feed.seenCounts"
    private static let capacity = 600

    /// Kayıtlı sayaçlar (gönderi kimliği → kaç oturumda görüldü).
    static func snapshot() -> [UUID: Int] {
        guard let raw = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else { return [:] }
        var out: [UUID: Int] = [:]
        for (k, v) in raw { if let id = UUID(uuidString: k) { out[id] = v } }
        return out
    }

    /// Bu oturumda ekrana gelen gönderiler; oturum başına bir kez sayılır.
    private static var seenThisSession: Set<UUID> = []

    static func markSeen(_ id: UUID) {
        guard !seenThisSession.contains(id) else { return }
        seenThisSession.insert(id)
        var raw = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
        raw[id.uuidString, default: 0] += 1
        // Sınırsız büyümesin: en eski yarısını at (sıra rastgele ama eski
        // gönderiler zaten akıştan düşmüş oluyor).
        if raw.count > capacity {
            for k in raw.keys.prefix(raw.count - capacity / 2) { raw.removeValue(forKey: k) }
        }
        UserDefaults.standard.set(raw, forKey: key)
    }
}
