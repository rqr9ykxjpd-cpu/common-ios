import SwiftUI
import UserNotifications

// MARK: - AppState+ClubEvents
extension AppState {
    /// Kulüp sayfası açılınca: yaklaşan etkinlikler. Sessiz: gelmezse bölüm
    /// boş kalır (sunucu eskiyse ya da ağ yoksa).
    func loadClubEvents(_ clubID: UUID) async {
        guard let masa = service as? any ClubEventsManaging else { return }
        do { clubEvents[clubID] = try await masa.fetchClubEvents(clubID) }
        catch { guard !isCancellation(error) else { return } }
    }

    func fetchEventAttendees(_ eventID: UUID) async throws -> [StudentProfile] {
        guard let masa = service as? any ClubEventsManaging else { return [] }
        return try await masa.fetchEventAttendees(eventID)
    }

    /// "Katılıyorum" / vazgeç: ekranda hemen, sunucu reddederse geri alınır.
    /// Katılınca hatırlatma kurulur; bildirim izni yoksa neden istendiği söylenir.
    func toggleAttendance(_ event: ClubEvent) {
        guard let masa = service as? any ClubEventsManaging else { return }
        let katil = !event.going
        guard !katil || requireStudent() else { return }
        updateEvent(event.id, in: event.clubID) {
            $0.going = katil
            $0.attendeeCount = max(0, $0.attendeeCount + (katil ? 1 : -1))
        }
        Haptics.impact(.light)
        Task {
            do {
                let sayi = try await masa.setEventAttendance(event.id, going: katil)
                updateEvent(event.id, in: event.clubID) { $0.attendeeCount = sayi }
                await syncEventReminders()
                if katil { promptForPushIfNeeded(.event) }
            } catch {
                updateEvent(event.id, in: event.clubID) {
                    $0.going = event.going
                    $0.attendeeCount = event.attendeeCount
                }
                showError(error, fallback: L10n.ClubEvents.attendFailed)
            }
        }
    }

    func saveClubEvent(_ draft: ClubEventDraft) async throws {
        guard let masa = service as? any ClubEventsManaging else { throw BackendServiceError.missingSession }
        _ = try await masa.saveClubEvent(draft)
        await loadClubEvents(draft.clubID)
        await loadClubs(silently: true)
        await syncEventReminders()
    }

    func cancelClubEvent(_ event: ClubEvent) async throws {
        guard let masa = service as? any ClubEventsManaging else { throw BackendServiceError.missingSession }
        try await masa.cancelClubEvent(event.id)
        withAnimation(BondTheme.Motion.smooth) {
            clubEvents[event.clubID]?.removeAll { $0.id == event.id }
        }
        await loadClubs(silently: true)
        await syncEventReminders()
    }

    private func updateEvent(_ id: UUID, in clubID: UUID, _ change: (inout ClubEvent) -> Void) {
        guard let i = clubEvents[clubID]?.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(BondTheme.Motion.snappy) { change(&clubEvents[clubID]![i]) }
    }

    // MARK: Hatırlatma

    static let eventReminderPrefix = "kulup-etkinlik-"

    /// Katıldığım etkinliklere başlamadan bir saat önce yerel bildirim. Sunucu
    /// tarafında zamanlanmış görev yok: liste açılışta, öne dönüşte ve katılım
    /// değişince okunur; saati değişen ya da iptal edilen etkinliğin
    /// hatırlatması da böylece güncellenir.
    func syncEventReminders() async {
        guard let masa = service as? any ClubEventsManaging, !isClubAccount else { return }
        let merkez = UNUserNotificationCenter.current()
        let izin = await merkez.notificationSettings().authorizationStatus
        guard izin == .authorized || izin == .provisional || izin == .ephemeral else { return }
        guard let benimkiler = try? await masa.fetchMyUpcomingEvents() else { return }

        let kurulacaklar = benimkiler.filter { $0.startsAt.addingTimeInterval(-3600) > .now }
        let istenen = Set(kurulacaklar.map { Self.eventReminderPrefix + $0.id.uuidString })
        let bekleyen = await merkez.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.eventReminderPrefix) }
        merkez.removePendingNotificationRequests(withIdentifiers: bekleyen.filter { !istenen.contains($0) })

        for etkinlik in kurulacaklar {
            let icerik = UNMutableNotificationContent()
            icerik.title = "\(etkinlik.clubName) · \(etkinlik.title)"
            icerik.body = etkinlik.placeLabel.map(L10n.ClubEvents.reminderBody) ?? L10n.ClubEvents.reminderBodyNoPlace
            icerik.sound = .default
            icerik.userInfo = ["clubID": etkinlik.clubID.uuidString]
            let an = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                     from: etkinlik.startsAt.addingTimeInterval(-3600))
            let istek = UNNotificationRequest(
                identifier: Self.eventReminderPrefix + etkinlik.id.uuidString,
                content: icerik,
                trigger: UNCalendarNotificationTrigger(dateMatching: an, repeats: false)
            )
            // Aynı kimlik yeniden eklenince eskisinin yerine geçer (saat değiştiyse).
            try? await merkez.add(istek)
        }
    }

    /// Hatırlatmaya dokunuldu: kulübün sayfası açılır.
    func openClubFromReminder(_ clubID: UUID) {
        Task {
            if clubs.isEmpty { await loadClubs(silently: true) }
            reminderClub = clubs.first { $0.id == clubID }
        }
    }
}
