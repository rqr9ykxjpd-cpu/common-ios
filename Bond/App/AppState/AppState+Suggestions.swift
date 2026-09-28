import SwiftUI

// MARK: - AppState+Suggestions
extension AppState {
    /// Satırda gösterilenler. Liste açılışta bir kez geliyor; bu arada bağlantı
    /// kurulan, kartı sağa geçilen ya da engellenen kişi hemen düşüyor.
    var visibleSuggestions: [PersonSuggestion] {
        let baglantilar = Set(conversations.map(\.profile.id))
        let engellenenler = Set(blockedProfiles.map(\.id))
        return suggestions.filter {
            !baglantilar.contains($0.id)
                && !rightSwipedProfileIDs.contains($0.id)
                && !engellenenler.contains($0.id)
                && $0.id != currentUserID
        }
    }

    /// Sessiz: öneri gelmezse satır görünmüyor, hata şeridi sohbetleri kirletmesin.
    func loadSuggestions() async {
        guard let oneren = service as? any PeopleSuggesting else { return }
        do {
            suggestions = try await oneren.fetchSuggestions(limit: 12)
        } catch {
            guard !isCancellation(error) else { return }
        }
    }

    /// × ile kaldırma: önce ekrandan, sonra sunucudan. Sunucu reddederse
    /// yerine geri koyuluyor ki kullanıcı kaldırıldı sanıp yeniden görmesin.
    func dismissSuggestion(_ suggestion: PersonSuggestion) {
        guard let oneren = service as? any PeopleSuggesting,
              let sira = suggestions.firstIndex(of: suggestion) else { return }
        suggestions.remove(at: sira)
        Haptics.selection()
        Task {
            do {
                try await oneren.dismissSuggestion(suggestion.id)
            } catch {
                guard !isCancellation(error) else { return }
                suggestions.insert(suggestion, at: min(sira, suggestions.count))
                showError(error, fallback: L10n.Suggestions.dismissFailed)
            }
        }
    }
}
