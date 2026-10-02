import Foundation

/// Kim nerede'de bir yerin durumu değişti: biri geldi ya da ayrıldı. Kim olduğu
/// söylenmez; ekran sayıyı ve listeyi kurallı sorgulardan yeniden çeker.
protocol PlaceActivityWatching: Sendable {
    func placeActivityStream() -> AsyncStream<UUID>
}
