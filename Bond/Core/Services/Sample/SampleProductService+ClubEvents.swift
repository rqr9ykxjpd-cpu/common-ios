#if DEBUG
import Foundation
import UIKit

/// Örnek modda etkinlikler: ilk kulübün iki etkinliği, bu açılış boyunca kalır.
extension SampleProductService: ClubEventsManaging {
    func fetchClubEvents(_ clubID: UUID) async throws -> [ClubEvent] {
        let kulupler = try await fetchClubs().clubs
        await SampleEventStore.shared.seedIfNeeded(firstClub: kulupler.first?.id,
                                                    place: SampleData.places.first)
        return await SampleEventStore.shared.events(for: clubID)
    }

    func fetchEventAttendees(_ eventID: UUID) async throws -> [StudentProfile] {
        await SampleEventStore.shared.attendees(eventID, me: SampleData.me)
    }

    func setEventAttendance(_ eventID: UUID, going: Bool) async throws -> Int {
        await SampleEventStore.shared.setGoing(eventID, going)
    }

    func saveClubEvent(_ draft: ClubEventDraft) async throws -> UUID {
        let yer = SampleData.places.first { $0.id == draft.placeID }
        let id = await SampleEventStore.shared.save(draft, placeName: yer?.name)
        // Sunucudaki gibi: yeni etkinlik, hesabı olan kulüpte akışa gönderi.
        if draft.id == nil, draft.clubID == (try? await fetchClubs().clubs.first?.id) {
            let gonderi = UUID()
            await store.insert(SampleData.clubEventPost(id: gonderi, caption: draft.title, createdAt: .now))
            await SampleEventStore.shared.link(id, post: gonderi)
        }
        return id
    }

    func cancelClubEvent(_ eventID: UUID) async throws {
        await SampleEventStore.shared.cancel(eventID)
    }

    func fetchMyUpcomingEvents() async throws -> [MyClubEvent] {
        let kulupler = try await fetchClubs().clubs
        return await SampleEventStore.shared.mine(clubs: kulupler)
    }

    func fetchPostEvents(_ postIDs: [UUID]) async throws -> [PostEvent] {
        let kulupler = try await fetchClubs().clubs
        await SampleEventStore.shared.seedIfNeeded(firstClub: kulupler.first?.id,
                                                    place: SampleData.places.first)
        return await SampleEventStore.shared.postEvents(postIDs, clubs: kulupler)
    }
}

private actor SampleEventStore {
    static let shared = SampleEventStore()
    private var events: [ClubEvent] = []
    private var seeded = false
    /// Örnekte etkinliğe gelenler: ilk birkaç örnek kişi.
    private var others: [UUID: [StudentProfile]] = [:]
    /// Etkinlik → akıştaki gönderisi.
    private var posts: [UUID: UUID] = [:]
    /// İptal edilenler listeden düşer, akıştaki kartta "iptal" yazar.
    private var cancelled: Set<UUID> = []

    func seedIfNeeded(firstClub: UUID?, place: CampusPlace?) {
        guard !seeded, let firstClub else { return }
        seeded = true
        let takvim = Calendar.current
        func gun(_ g: Int, _ saat: Int) -> Date {
            let d = takvim.date(byAdding: .day, value: g, to: .now) ?? .now
            return takvim.date(bySettingHour: saat, minute: 0, second: 0, of: d) ?? d
        }
        let kisiler = Array(SampleData.profiles.prefix(4))
        let ilk = ClubEvent(id: UUID(), clubID: firstClub, title: "Kampüs fotoğraf yürüyüşü",
                            details: "Hazırlık binasının önünden başlıyoruz, gün batımına kadar sahil yolu. Telefon da olur.",
                            startsAt: gun(2, 17), placeID: place?.id, placeName: place?.name, placeNote: "",
                            attendeeCount: kisiler.count, going: false,
                            attendeeAvatars: kisiler.prefix(3).compactMap { $0.imageAssetName.flatMap(UIImageAsset.fileURL(named:)) })
        let ikinci = ClubEvent(id: UUID(), clubID: firstClub, title: "Karanlık oda atölyesi",
                               details: "", startsAt: gun(6, 19), placeID: nil, placeName: nil,
                               placeNote: "Güzel Sanatlar B blok 204", attendeeCount: 2, going: false,
                               attendeeAvatars: kisiler.suffix(2).compactMap { $0.imageAssetName.flatMap(UIImageAsset.fileURL(named:)) })
        events = [ilk, ikinci]
        posts[ilk.id] = SampleData.photoClubEventPostID
        others[ilk.id] = kisiler
        others[ikinci.id] = Array(kisiler.suffix(2))
    }

    func events(for clubID: UUID) -> [ClubEvent] {
        events.filter { $0.clubID == clubID && !cancelled.contains($0.id) && $0.startsAt > .now.addingTimeInterval(-3 * 3600) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func attendees(_ eventID: UUID, me: StudentProfile) -> [StudentProfile] {
        let digerleri = others[eventID] ?? []
        guard events.first(where: { $0.id == eventID })?.going == true else { return digerleri }
        return digerleri + [me]
    }

    func setGoing(_ eventID: UUID, _ going: Bool) -> Int {
        guard let i = events.firstIndex(where: { $0.id == eventID }) else { return 0 }
        if events[i].going != going {
            events[i].going = going
            events[i].attendeeCount += going ? 1 : -1
        }
        return events[i].attendeeCount
    }

    func save(_ draft: ClubEventDraft, placeName: String?) -> UUID {
        if let id = draft.id, let i = events.firstIndex(where: { $0.id == id }) {
            events[i].title = draft.title
            events[i].details = draft.details
            events[i].startsAt = draft.startsAt
            events[i].placeID = draft.placeID
            events[i].placeName = placeName
            events[i].placeNote = draft.placeNote
            return id
        }
        let yeni = ClubEvent(id: UUID(), clubID: draft.clubID, title: draft.title, details: draft.details,
                             startsAt: draft.startsAt, placeID: draft.placeID, placeName: placeName,
                             placeNote: draft.placeNote, attendeeCount: 0, going: false, attendeeAvatars: [])
        events.append(yeni)
        return yeni.id
    }

    func cancel(_ eventID: UUID) { cancelled.insert(eventID) }

    func link(_ eventID: UUID, post: UUID) { posts[eventID] = post }

    func postEvents(_ postIDs: [UUID], clubs: [CampusClub]) -> [PostEvent] {
        let istenen = Set(postIDs)
        return events.compactMap { e in
            guard let gonderi = posts[e.id], istenen.contains(gonderi),
                  let kulup = clubs.first(where: { $0.id == e.clubID }) else { return nil }
            return PostEvent(postID: gonderi, event: e, clubName: kulup.name, clubIcon: kulup.icon,
                             accentHex: kulup.accentHex, cancelled: cancelled.contains(e.id))
        }
    }

    func mine(clubs: [CampusClub]) -> [MyClubEvent] {
        events.filter { $0.going && !cancelled.contains($0.id) && $0.startsAt > .now }.map { e in
            MyClubEvent(id: e.id, clubID: e.clubID, clubName: clubs.first { $0.id == e.clubID }?.name ?? "",
                        title: e.title, startsAt: e.startsAt, placeLabel: e.placeLabel)
        }
    }
}
#endif
