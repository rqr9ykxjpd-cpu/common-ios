import EventKit
import EventKitUI
import SwiftUI

/// Etkinlik tarihinin yazılışı: "Bugün 19:00", "Yarın 19:00", "Cuma 19:00",
/// daha ilerisi "25 Ekim Cumartesi 19:00". Başladıysa "Şimdi".
enum ClubEventFormat {
    static func when(_ date: Date, now: Date = .now) -> String {
        if date <= now {
            // Başlayalı üç saat olmadıysa "Şimdi"; akıştaki eski etkinlik tarihiyle.
            return now.timeIntervalSince(date) < 3 * 3600 ? L10n.ClubEvents.now : absolute(date)
        }
        let takvim = Calendar.current
        let saat = time(date)
        if takvim.isDateInToday(date) { return L10n.ClubEvents.today(saat) }
        if takvim.isDateInTomorrow(date) { return L10n.ClubEvents.tomorrow(saat) }
        let gunFarki = takvim.dateComponents([.day], from: takvim.startOfDay(for: now), to: takvim.startOfDay(for: date)).day ?? 0
        if gunFarki < 7 {
            return date.formatted(.dateTime.weekday(.wide).locale(L10n.appLocale)) + " " + saat
        }
        return date.formatted(.dateTime.day().month(.wide).weekday(.wide).locale(L10n.appLocale)) + " " + saat
    }

    /// "18 Ekim Cumartesi"
    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).weekday(.wide).locale(L10n.appLocale))
    }

    /// "18 Ekim Cumartesi, 19:00": paylaşırken, okunduğu gün değişse de doğru.
    static func absolute(_ date: Date) -> String {
        fullDate(date) + ", " + time(date)
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(L10n.appLocale))
    }

    /// Gün şeridinde: "Cmt"
    static func weekdayShort(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(L10n.appLocale))
    }

    /// Bir haftadan yakın: "Cumartesi 19:00" yazılıyor, tam tarih ayrıca gerekiyor.
    static func isWithinWeek(_ date: Date, now: Date = .now) -> Bool {
        let takvim = Calendar.current
        let gunFarki = takvim.dateComponents([.day], from: takvim.startOfDay(for: now), to: takvim.startOfDay(for: date)).day ?? 0
        return gunFarki < 7
    }

    /// Bugün ya da başlamış: kartta koyu yazılıyor.
    static func isSoon(_ date: Date) -> Bool {
        date <= .now || Calendar.current.isDateInToday(date)
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(L10n.appLocale))
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(L10n.appLocale))
            .uppercased(with: L10n.appLocale)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}

/// Kulüp sayfasında bir etkinlik: tarih bloğu, başlık, saat ve yer, kimlerin
/// geldiği; sağda "Katılıyorum". Karta dokununca etkinlik sayfası açılır.
struct ClubEventCard: View {
    @Environment(AppState.self) private var appState
    let event: ClubEvent
    let accent: Color
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 14) {
                    ClubEventDateBlock(date: event.startsAt, accent: accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(BondTheme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        whenLine
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ClubEventAttendeeStack(avatars: event.attendeeAvatars)
                Text(event.attendeeCount == 0 ? L10n.ClubEvents.noneYet : L10n.ClubEvents.attendeeCount(event.attendeeCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                Spacer(minLength: 8)
                ClubEventGoingButton(event: event, accent: accent, compact: true)
            }
        }
        .padding(BondTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.event.\(event.id)")
    }

    /// "Bugün 19:00 · Kütüphane": bugünse saat koyu.
    private var whenLine: Text {
        let ne = ClubEventFormat.when(event.startsAt)
        let zaman = ClubEventFormat.isSoon(event.startsAt)
            ? Text(ne).foregroundStyle(BondTheme.ink).fontWeight(.semibold)
            : Text(ne)
        guard let yer = event.placeLabel else { return zaman }
        return Text("\(zaman) · \(yer)")
    }
}

/// Kartın solundaki tarih: ay kulübün renginde, gün büyük.
struct ClubEventDateBlock: View {
    let date: Date
    let accent: Color
    var background: Color = BondTheme.paper

    var body: some View {
        VStack(spacing: 0) {
            Text(ClubEventFormat.month(date))
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(ClubEventFormat.day(date))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(BondTheme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: 50, height: 54)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// "Katılıyorum" / "Katılıyorsun ✓". Kartta küçük, etkinlik sayfasında geniş.
struct ClubEventGoingButton: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let event: ClubEvent
    let accent: Color
    var compact = false

    var body: some View {
        Button { appState.toggleAttendance(event) } label: {
            HStack(spacing: 6) {
                if event.going {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(event.going ? L10n.ClubEvents.youreGoing : L10n.ClubEvents.going)
            }
            .font(compact ? .subheadline.weight(.semibold) : .headline)
            .foregroundStyle(event.going ? BondTheme.ink : BondTheme.paper)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(minHeight: compact ? 36 : 52)
            .background(event.going ? BondTheme.paper : BondTheme.ink, in: Capsule())
            .overlay(Capsule().stroke(event.going ? BondTheme.hairline : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: event.going)
        .accessibilityIdentifier("club.event.going")
    }
}

/// Akışta kulübün etkinlik gönderisi: metin yerine etkinliğin kendisi.
/// Dokununca etkinlik sayfası açılır; Katılıyorum kartın içinde.
struct ClubEventPostBlock: View {
    @Environment(AppState.self) private var appState
    let postEvent: PostEvent
    @State private var showsDetail = false

    private var event: ClubEvent { postEvent.event }
    private var accent: Color { Color(hex: postEvent.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Button { showsDetail = true } label: {
                HStack(alignment: .top, spacing: 14) {
                    ClubEventDateBlock(date: event.startsAt, accent: accent)
                        .opacity(postEvent.cancelled ? 0.5 : 1)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(postEvent.cancelled ? BondTheme.muted : BondTheme.ink)
                            .strikethrough(postEvent.cancelled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text([ClubEventFormat.when(event.startsAt), event.placeLabel].compactMap { $0 }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !event.details.isEmpty, !postEvent.cancelled {
                            Text(event.details)
                                .font(.subheadline)
                                .foregroundStyle(BondTheme.ink)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(postEvent.cancelled)

            HStack(spacing: 10) {
                if postEvent.cancelled {
                    Text(L10n.ClubEvents.cancelledLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BondTheme.muted)
                } else {
                    ClubEventAttendeeStack(avatars: event.attendeeAvatars)
                    Text(event.attendeeCount == 0 ? L10n.ClubEvents.noneYet : L10n.ClubEvents.attendeeCount(event.attendeeCount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if postEvent.acceptsAttendance {
                    ClubEventGoingButton(event: event, accent: accent, compact: true)
                }
            }
        }
        .padding(BondTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.event.\(event.id)")
        .sheet(isPresented: $showsDetail) {
            ClubEventDetailView(clubID: event.clubID, eventID: event.id, clubName: postEvent.clubName,
                                accent: accent, canManage: appState.canManage(event.clubID))
                .presentationDragIndicator(.visible)
        }
    }
}

/// Katılanların ilk üçünün fotoğrafı, üst üste.
struct ClubEventAttendeeStack: View {
    let avatars: [URL]

    var body: some View {
        if !avatars.isEmpty {
            HStack(spacing: -8) {
                ForEach(Array(avatars.prefix(3).enumerated()), id: \.offset) { _, url in
                    ProfileMedia(url: url, data: nil)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(BondTheme.surface, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
        }
    }
}

/// Etkinliğin sayfası: ayrıntı, katılım, kimlerin geldiği. Yönetenler
/// buradan düzenler ve iptal eder.
struct ClubEventDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let clubID: UUID
    let eventID: UUID
    let clubName: String
    let accent: Color
    let canManage: Bool

    @State private var attendees: [StudentProfile] = []
    @State private var attendeesLoaded = false
    @State private var editing = false
    @State private var confirmCancel = false
    @State private var cardProfile: StudentProfile?
    @State private var addingToCalendar = false

    /// Kulüp sayfasından ya da akıştaki gönderiden açılmış olabilir.
    private var event: ClubEvent? {
        appState.clubEvents[clubID]?.first { $0.id == eventID } ?? appState.postEvent(for: eventID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    content(event)
                } else {
                    // İptal edildi ya da süresi geçti.
                    Color.clear.onAppear { dismiss() }
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.ClubEvents.detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                if canManage, event != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(L10n.ClubEvents.edit, systemImage: "pencil") { editing = true }
                            Button(L10n.ClubEvents.cancelEvent, systemImage: "xmark.circle", role: .destructive) {
                                confirmCancel = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .accessibilityLabel(L10n.Chat.options)
                    }
                }
            }
            .sheet(isPresented: $editing) {
                if let event { ClubEventComposer(draft: ClubEventDraft(event: event), clubName: clubName, accent: accent) }
            }
            .sheet(isPresented: $addingToCalendar) {
                if let event {
                    ClubEventCalendarSheet(event: event, clubName: clubName) { eklendi in
                        addingToCalendar = false
                        if eklendi { appState.show(L10n.ClubEvents.addedToCalendar) }
                    }
                    .ignoresSafeArea()
                }
            }
            .sheet(item: $cardProfile) { profile in
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
                }
            }
            .confirmationDialog(L10n.ClubEvents.cancelConfirm(event?.title ?? ""),
                                isPresented: $confirmCancel, titleVisibility: .visible) {
                Button(L10n.ClubEvents.cancelEvent, role: .destructive) {
                    guard let event else { return }
                    Task {
                        do {
                            try await appState.cancelClubEvent(event)
                            Haptics.success()
                            appState.show(L10n.ClubEvents.cancelled)
                        } catch {
                            appState.showError(error, fallback: L10n.ClubEvents.saveFailed)
                        }
                    }
                }
                Button(L10n.ClubEvents.keep, role: .cancel) {}
            } message: {
                Text(L10n.ClubEvents.cancelBody)
            }
            .task(id: event?.attendeeCount) { await loadAttendees() }
        }
    }

    private func content(_ event: ClubEvent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Eyebrow(text: clubName, color: BondTheme.muted)
                    Text(event.title)
                        .editorialTitle(32)
                        .fixedSize(horizontal: false, vertical: true)
                }

                infoCard(event)

                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    ClubEventGoingButton(event: event, accent: accent)
                    if event.going {
                        Text(L10n.ClubEvents.reminderNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                    HStack(spacing: BondTheme.Space.sm) {
                        Button { addingToCalendar = true } label: {
                            Label(L10n.ClubEvents.addToCalendar, systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("club.event.calendar")
                        ShareLink(item: shareText(event)) {
                            Label(L10n.ClubEvents.share, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("club.event.share")
                    }
                    .buttonStyle(.secondaryCapsule)
                    .disabled(event.hasStarted)
                }
                .animation(BondTheme.Motion.smooth, value: event.going)

                if !event.details.isEmpty {
                    VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                        Eyebrow(text: L10n.ClubEvents.about, color: BondTheme.muted)
                        Text(event.details)
                            .font(.body)
                            .foregroundStyle(BondTheme.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                    Eyebrow(text: L10n.ClubEvents.attendees + " · \(event.attendeeCount)", color: BondTheme.muted)
                        .contentTransition(.numericText())
                    if attendees.isEmpty {
                        if attendeesLoaded {
                            Text(L10n.ClubEvents.attendeesEmpty)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView().frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(attendees) { kisi in
                                if kisi.id != attendees.first?.id { Divider().padding(.leading, 68) }
                                ClubMemberRowView(member: ClubMember(profile: kisi, isManager: false)) {
                                    if kisi.id != appState.currentUserID { cardProfile = kisi }
                                }
                            }
                        }
                        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .foregroundStyle(BondTheme.ink)
            .padding(BondTheme.Space.lg)
        }
    }

    /// Ne zaman ve nerede, kartın diliyle: solda tarih bloğu, yanında
    /// "Yarın 19:00" ve tam tarih; altında yer.
    private func infoCard(_ event: ClubEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ClubEventDateBlock(date: event.startsAt, accent: accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ClubEventFormat.when(event.startsAt))
                        .font(.headline)
                        .foregroundStyle(BondTheme.ink)
                    if ClubEventFormat.isWithinWeek(event.startsAt), !event.hasStarted {
                        Text(ClubEventFormat.fullDate(event.startsAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(BondTheme.Space.md)
            if let yer = event.placeLabel {
                Divider().padding(.leading, 64 + BondTheme.Space.md)
                HStack(spacing: 14) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(BondTheme.icon)
                        .frame(width: 50)
                    Text(yer)
                        .font(.body.weight(.medium))
                        .foregroundStyle(BondTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(BondTheme.Space.md)
            }
        }
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// WhatsApp grubuna, hikâyeye: tarih göreli değil, okunduğu gün de doğru.
    private func shareText(_ event: ClubEvent) -> String {
        var satirlar = ["\(clubName) · \(event.title)"]
        satirlar.append([ClubEventFormat.absolute(event.startsAt), event.placeLabel].compactMap { $0 }.joined(separator: " · "))
        satirlar.append("")
        satirlar.append(L10n.ClubEvents.shareFooter(AppLinks.appStore.absoluteString))
        return satirlar.joined(separator: "\n")
    }

    private func loadAttendees() async {
        guard let liste = try? await appState.fetchEventAttendees(eventID) else {
            attendeesLoaded = true
            return
        }
        withAnimation(BondTheme.Motion.smooth) { attendees = liste }
        attendeesLoaded = true
    }
}

/// "Takvime ekle": iOS'un kendi etkinlik ekranı. iOS 17'den beri uygulamanın
/// dışında açılıyor; takvim izni istemiyor, kişi kaydederse eklenir.
struct ClubEventCalendarSheet: UIViewControllerRepresentable {
    let event: ClubEvent
    let clubName: String
    let finished: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let depo = EKEventStore()
        let kayit = EKEvent(eventStore: depo)
        kayit.title = event.title
        kayit.startDate = event.startsAt
        kayit.endDate = event.startsAt.addingTimeInterval(2 * 3600)
        kayit.location = event.placeLabel
        kayit.notes = event.details.isEmpty ? clubName : clubName + "\n\n" + event.details
        kayit.addAlarm(EKAlarm(relativeOffset: -3600))
        let ekran = EKEventEditViewController()
        ekran.eventStore = depo
        ekran.event = kayit
        ekran.editViewDelegate = context.coordinator
        return ekran
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        let finished: (Bool) -> Void
        init(finished: @escaping (Bool) -> Void) { self.finished = finished }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            finished(action == .saved)
        }
    }
}
