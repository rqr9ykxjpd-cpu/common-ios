import Foundation

/// Gönderiye düğme ekleme/kaldırma. Ayrı protokol (bkz. `PeopleSuggesting`).
protocol PostActionSetting: Sendable {
    /// nil düğmeyi kaldırır. Yetki sunucuda: kurucu ya da Common hesabı.
    func setPostAction(_ postID: UUID, action: PostAction?) async throws
}
