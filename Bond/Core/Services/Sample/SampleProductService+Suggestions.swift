#if DEBUG
import Foundation

/// Örnek modda öneriler: bağlantı kurulmamış kişiler, her biri farklı bir
/// sebeple (ortak kulüp, ortak bağlantı, ortak ilgi). Selin örnek veride
/// engelli; engel kuralını göstermek için listede ama önerilmiyor.
/// Kaldırılanlar bu açılış boyunca bir daha gelmiyor.
extension SampleProductService: PeopleSuggesting {
    func fetchSuggestions(limit: Int) async throws -> [PersonSuggestion] {
        // Engellenenler önerilmiyor; sunucudaki fonksiyonla aynı kural.
        let kaldirilan = await SampleSuggestionStore.shared.dismissed
            .union(SampleData.blockedProfiles.map(\.id))
        let kisiler: [(String, PersonSuggestion.Reason)] = [
            ("Duru", .club("Fotoğraf Kulübü")),
            ("Arda", .mutual(2)),
            ("Selin", .interests(3))
        ]
        // Sohbeti temizlenen ve sonra yazışılmayan bağlantılar en başta.
        let temizlenen = await SampleClearedStore.shared.ids
        let baglantilar = try await fetchConversations()
            .filter { temizlenen.contains($0.id) && $0.messages.isEmpty }
            .map { PersonSuggestion(profile: $0.profile, reason: .connection) }
        let digerleri = kisiler.compactMap { ad, sebep -> PersonSuggestion? in
            guard let profil = SampleData.profiles.first(where: { $0.name == ad }),
                  !kaldirilan.contains(profil.id) else { return nil }
            return PersonSuggestion(profile: profil, reason: sebep)
        }
        return Array((baglantilar + digerleri).prefix(limit))
    }

    func dismissSuggestion(_ profileID: UUID) async throws {
        await SampleSuggestionStore.shared.dismiss(profileID)
    }
}

private actor SampleSuggestionStore {
    static let shared = SampleSuggestionStore()
    private(set) var dismissed: Set<UUID> = []
    func dismiss(_ id: UUID) { dismissed.insert(id) }
}
#endif
