import SwiftUI

// MARK: - AppState+Discovery
extension AppState {
    /// "Geç" dediklerini geri getirip desteyi baştan yükler. Kalıcı bir karar
    /// olmamalı: kampüste birkaç bin kişi var, bir kere sola kaydırmak kimseyi
    /// ömür boyu silmemeli.
    func reloadDiscoveryIncludingPasses() async {
        do { try await service.resetPasses() }
        catch { showError(error, fallback: L10n.Discovery.rewindFailed) }
        await loadDiscovery(reset: true)
    }

    func loadDiscovery(reset: Bool = false) async {
        guard !isLoadingDiscovery else { return }
        isLoadingDiscovery = true
        discoveryError = nil
        defer { isLoadingDiscovery = false }
        do {
            let offset = reset ? 0 : profiles.count
            let candidates = try await service.fetchDiscoveryCandidates(filters: discoveryFilters, offset: offset, limit: 20)
            if reset { profiles = candidates } else {
                let existing = Set(profiles.map(\.id))
                profiles.append(contentsOf: candidates.filter { !existing.contains($0.id) })
            }
        } catch {
            discoveryError = UserFacingError.message(error, fallback: L10n.Discovery.loadFailed)
        }
    }

    func applyDiscoveryFilters(_ filters: DiscoveryFilters) async {
        discoveryFilters = filters
        await loadDiscovery(reset: true)
    }

    func react(to profile: StudentProfile, liked: Bool) async {
        guard !isReactingToProfile else { return }
        isReactingToProfile = true
        discoveryError = nil
        defer { isReactingToProfile = false }
        do {
            let result = try await service.reactToProfile(profileID: profile.id, liked: liked)
            profiles.removeAll { $0.id == profile.id }
            if result.matched, let matchID = result.matchID {
                currentMatch = profile
                _ = conversationID(for: profile, matchID: matchID)
                // Backend modunda eşleşme bildirimini veritabanı trigger'ı üretiyor; burada
                // ayrıca eklersek aynı bildirim iki kez görünür.
            }
            if profiles.count < 3 { await loadDiscovery() }
        } catch {
            discoveryError = UserFacingError.message(error, fallback: L10n.Discovery.actionFailed)
        }
    }
}
