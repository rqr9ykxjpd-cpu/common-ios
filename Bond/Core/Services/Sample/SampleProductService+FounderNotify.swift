#if DEBUG
import Foundation

extension SampleProductService: FounderNotifying {
    func notifyUser(_ userID: UUID, title: String, body: String) async throws {}
}
#endif
