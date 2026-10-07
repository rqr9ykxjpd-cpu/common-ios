#if DEBUG
import Foundation

/// Örnek modda kulüp yönetimi: örnek kulüpler, ilkini "ben" yönetiyorum.
/// Yapılan değişiklikler bu açılış boyunca kalıyor.
extension SampleProductService: ClubManaging {
    func fetchClubExtras() async throws -> [UUID: ClubExtras] { await SampleClubStore.shared.extras }

    func fetchManagedClubIDs() async throws -> Set<UUID> {
        guard let ilk = try await fetchClubs().clubs.first else { return [] }
        return [ilk.id]
    }

    func fetchAdminClubs() async throws -> [ClubAdminEntry] {
        let ek = await SampleClubStore.shared.extras
        let kayitli = await SampleClubStore.shared.drafts
        let kulupler = try await fetchClubs().clubs
        return kulupler.map { club in
            let taslak = kayitli[club.id] ?? ClubDraft(
                id: club.id, name: club.name, summary: club.summary, icon: club.icon,
                nextEvent: club.nextEvent, placeID: club.meetingPlace?.id, accentHex: club.accentHex,
                instagram: ek[club.id]?.instagram ?? "", contactEmail: ek[club.id]?.contactEmail ?? "",
                isActive: true, logoURL: nil)
            return ClubAdminEntry(id: club.id, draft: taslak, memberCount: club.memberCount,
                                  managerCount: club.id == kulupler.first?.id ? 1 : 0)
        }
    }

    func saveClub(_ draft: ClubDraft) async throws -> UUID {
        let id = draft.id ?? UUID()
        var kayit = draft
        kayit.id = id
        await SampleClubStore.shared.save(kayit)
        return id
    }

    func uploadClubLogo(_ clubID: UUID, imageData: Data) async throws -> URL? { nil }

    func fetchClubPeople(_ clubID: UUID) async throws -> [ClubPerson] {
        // Yönetici yalnızca ilk kulüpte var; liste sayılarıyla tutarlı kalsın.
        let ilk = try await fetchClubs().clubs.first?.id
        return SampleData.profiles.prefix(4).enumerated().map { sira, kisi in
            ClubPerson(id: kisi.id, name: kisi.name, username: kisi.name.lowercased(),
                       avatarURL: nil, isManager: sira == 0 && clubID == ilk,
                       joinedAt: .now.addingTimeInterval(Double(-86_400 * (sira + 1))))
        }
    }

    func setClubManager(_ clubID: UUID, userID: UUID, enabled: Bool) async throws -> Bool {
        await SampleClubManagerStore.shared.set(userID, clubID, enabled)
        return enabled
    }

    func removeClubMember(_ clubID: UUID, userID: UUID) async throws {}
}

private actor SampleClubStore {
    static let shared = SampleClubStore()
    private(set) var drafts: [UUID: ClubDraft] = [:]
    private(set) var extras: [UUID: ClubExtras] = [:]

    func save(_ draft: ClubDraft) {
        guard let id = draft.id else { return }
        drafts[id] = draft
        extras[id] = ClubExtras(logoURL: draft.logoURL,
                                instagram: draft.instagram.isEmpty ? nil : draft.instagram,
                                contactEmail: draft.contactEmail.isEmpty ? nil : draft.contactEmail)
    }
}
#endif
