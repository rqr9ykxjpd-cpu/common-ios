import SwiftUI

/// Etkinlik tarihinin yazılışı: "Bugün 19:00", "Yarın 19:00", "Cuma 19:00",
/// daha ilerisi "25 Ekim Cumartesi 19:00". Başladıysa "Şimdi".
enum ClubEventFormat {
    static func when(_ date: Date, now: Date = .now) -> String {
        if date <= now { return L10n.ClubEvents.now }
        let takvim = Calendar.current
        let saat = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(L10n.appLocale))
        if takvim.isDateInToday(date) { return L10n.ClubEvents.today(saat) }
        if takvim.isDateInTomorrow(date) { return L10n.ClubEvents.tomorrow(saat) }
        let gunFarki = takvim.dateComponents([.day], from: takvim.startOfDay(for: now), to: takvim.startOfDay(for: date)).day ?? 0
        if gunFarki < 7 {
            return date.formatted(.dateTime.weekday(.wide).locale(L10n.appLocale)) + " " + saat
        }
        return date.formatted(.dateTime.day().month(.wide).weekday(.wide).locale(L10n.appLocale)) + " " + saat
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
                    dateBlock
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(BondTheme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text([ClubEventFormat.when(event.startsAt), event.placeLabel].compactMap { $0 }.joined(separator: " · "))
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

    private var dateBlock: some View {
        VStack(spacing: 0) {
            Text(ClubEventFormat.month(event.startsAt))
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(ClubEventFormat.day(event.startsAt))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(BondTheme.ink)
                .monospacedDigit()
        }
        .frame(width: 50, height: 54)
        .background(BondTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .foregroundStyle(event.going ? BondTheme.ink : Color.white)
            .padding(.horizontal, compact ? 14 : 20)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(minHeight: compact ? 36 : 52)
            .background(event.going ? BondTheme.paper : accent, in: Capsule())
            .overlay(Capsule().stroke(event.going ? BondTheme.hairline : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: event.going)
        .accessibilityIdentifier("club.event.going")
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

    private var event: ClubEvent? { appState.clubEvents[clubID]?.first { $0.id == eventID } }

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
                if let event { ClubEventComposer(draft: ClubEventDraft(event: event)) }
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
                    Eyebrow(text: clubName, color: accent)
                    Text(event.title)
                        .editorialTitle(32)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label(ClubEventFormat.when(event.startsAt), systemImage: "calendar")
                    if let yer = event.placeLabel {
                        Label(yer, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.body.weight(.medium))
                .foregroundStyle(BondTheme.ink)

                if !event.details.isEmpty {
                    Text(event.details)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    ClubEventGoingButton(event: event, accent: accent)
                    if event.going {
                        Text(L10n.ClubEvents.reminderNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .animation(BondTheme.Motion.smooth, value: event.going)

                VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                    Eyebrow(text: L10n.ClubEvents.attendees + " · \(event.attendeeCount)", color: BondTheme.muted)
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

    private func loadAttendees() async {
        guard let liste = try? await appState.fetchEventAttendees(eventID) else {
            attendeesLoaded = true
            return
        }
        withAnimation(BondTheme.Motion.smooth) { attendees = liste }
        attendeesLoaded = true
    }
}

/// Etkinlik aç / düzenle: başlık, ne zaman, nerede, açıklama.
struct ClubEventComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var draft: ClubEventDraft
    @State private var saving = false
    @State private var failure: String?

    private var canSave: Bool {
        !saving && !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(BondTheme.burntOrangeText)
                    }
                }
                Section {
                    TextField(L10n.ClubEvents.titlePlaceholder, text: $draft.title, axis: .vertical)
                        .font(.headline)
                        .lineLimit(1...3)
                        .onChange(of: draft.title) { _, yeni in
                            if yeni.count > 80 { draft.title = String(yeni.prefix(80)) }
                        }
                        .accessibilityIdentifier("event.title")
                }
                Section {
                    DatePicker(L10n.ClubEvents.when, selection: $draft.startsAt,
                               in: Date.now.addingTimeInterval(-3600)...Date.now.addingTimeInterval(365 * 24 * 3600),
                               displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, L10n.appLocale)
                }
                Section(L10n.ClubEvents.place) {
                    Picker(L10n.ClubEvents.campusPlace, selection: $draft.placeID) {
                        Text(L10n.ClubEvents.noPlace).tag(UUID?.none)
                        ForEach(appState.places) { yer in
                            Text(yer.name).tag(Optional(yer.id))
                        }
                    }
                    TextField(L10n.ClubEvents.placeNotePlaceholder, text: $draft.placeNote)
                        .onChange(of: draft.placeNote) { _, yeni in
                            if yeni.count > 80 { draft.placeNote = String(yeni.prefix(80)) }
                        }
                }
                Section(L10n.ClubEvents.details) {
                    TextField(L10n.ClubEvents.detailsPlaceholder, text: $draft.details, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: draft.details) { _, yeni in
                            if yeni.count > 500 { draft.details = String(yeni.prefix(500)) }
                        }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(draft.id == nil ? L10n.ClubEvents.newTitle : L10n.ClubEvents.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button(L10n.ClubEvents.save) { Task { await save() } }
                            .disabled(!canSave)
                            .accessibilityIdentifier("event.save")
                    }
                }
            }
            .task { if appState.places.isEmpty { await appState.loadPlaces(silently: true) } }
        }
    }

    private func save() async {
        guard canSave else { return }
        saving = true
        defer { saving = false }
        failure = nil
        do {
            try await appState.saveClubEvent(draft)
            Haptics.success()
            appState.show(L10n.ClubEvents.saved)
            dismiss()
        } catch {
            Haptics.warning()
            failure = UserFacingError.message(error, fallback: L10n.ClubEvents.saveFailed)
        }
    }
}
