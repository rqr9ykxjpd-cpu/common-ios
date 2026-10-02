#if DEBUG
import Foundation

/// Örnek modda başka cihaz yok; akış sessiz kalır.
extension SampleProductService: PlaceActivityWatching {
    func placeActivityStream() -> AsyncStream<UUID> { AsyncStream { _ in } }
}
#endif
