import SwiftUI

// MARK: - AppState+LivePlaces
extension AppState {
    /// Başkası bir yerde "Buradayım" deyince ya da ayrılınca saniyeler içinde
    /// sayılar ve açık kişi listesi yenilenir. Peş peşe gelen damgalar tek
    /// yenilemeye toplanır.
    func startPlaceListener() {
        guard placeListenerTask == nil, let canli = service as? any PlaceActivityWatching else { return }
        placeListenerTask = Task { [weak self] in
            var bekleyen: Task<Void, Never>?
            for await _ in canli.placeActivityStream() {
                guard let self else { return }
                bekleyen?.cancel()
                bekleyen = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, let self else { return }
                    await self.loadPlacePresence()
                    self.placeActivityRevision += 1
                }
            }
        }
    }

    func stopPlaceListener() {
        placeListenerTask?.cancel()
        placeListenerTask = nil
    }
}
