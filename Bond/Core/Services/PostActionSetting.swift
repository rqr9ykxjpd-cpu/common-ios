import Foundation

/// Gönderiye düğme ekleme/kaldırma. Ayrı protokol (bkz. `PeopleSuggesting`).
protocol PostActionSetting: Sendable {
    /// nil düğmeyi kaldırır. Yetki sunucuda: yalnızca Common hesabı, kendi gönderisi.
    func setPostAction(_ postID: UUID, action: PostAction?) async throws
}
