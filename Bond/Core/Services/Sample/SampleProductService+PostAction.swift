#if DEBUG
import Foundation

/// Örnek modda düğme yalnızca ekranda değişir; akış yenilenince gider.
extension SampleProductService: PostActionSetting {
    func setPostAction(_ postID: UUID, action: PostAction?) async throws {}
}
#endif
