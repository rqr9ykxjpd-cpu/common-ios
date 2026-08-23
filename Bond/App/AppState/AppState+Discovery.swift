import SwiftUI

// MARK: - AppState+Discovery
extension AppState {
    /// "Geç" dediklerini geri getirip desteyi baştan yükler.
    ///
    /// Kurucu/moderatör sunucuda tüm tepkilerini siler (eşleşmeler kalır).
    /// Yükleme yarışı: `force` yeni bir nesil başlatır; eski isteğin sonucu
    /// desteyi ezmez.
    func reloadDiscoveryIncludingPasses() async {
        do {
            try await service.resetPasses()
        } catch {
            showError(error, fallback: L10n.Discovery.rewindFailed)
            return
        }
        await loadDiscovery(reset: true, force: true)
    }

    func loadDiscovery(reset: Bool = false, force: Bool = false) async {
        if isLoadingDiscovery && !force { return }

        discoveryLoadGeneration &+= 1
        let generation = discoveryLoadGeneration
        isLoadingDiscovery = true
        discoveryError = nil
        defer {
            if discoveryLoadGeneration == generation {
                isLoadingDiscovery = false
            }
        }

        do {
            let offset = reset ? 0 : profiles.count
            let candidates = try await service.fetchDiscoveryCandidates(
                filters: discoveryFilters,
                offset: offset,
                limit: 20
            )
            guard discoveryLoadGeneration == generation else { return }
            if reset {
                profiles = candidates
            } else {
                let existing = Set(profiles.map(\.id))
                profiles.append(contentsOf: candidates.filter { !existing.contains($0.id) })
            }
            // Kurucu testinde filtre yüzünden boş kaldıysa bir kez varsayılanla dene.
            if reset,
               candidates.isEmpty,
               (myBadge == .founder || myBadge == .moderator),
               discoveryFilters.activeCount > 0 {
                discoveryFilters = DiscoveryFilters()
                let again = try await service.fetchDiscoveryCandidates(
                    filters: discoveryFilters,
                    offset: 0,
                    limit: 20
                )
                guard discoveryLoadGeneration == generation else { return }
                profiles = again
            }
        } catch {
            guard discoveryLoadGeneration == generation else { return }
            discoveryError = UserFacingError.message(error, fallback: L10n.Discovery.loadFailed)
        }
    }

    func applyDiscoveryFilters(_ filters: DiscoveryFilters) async {
        discoveryFilters = filters
        await loadDiscovery(reset: true, force: true)
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
