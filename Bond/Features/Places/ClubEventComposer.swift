import SwiftUI

/// Etkinlik aç / düzenle. En üstte kulüp sayfasındaki kartın kendisi (tarih
/// bloğu, başlık, saat ve yer): yazarken nasıl görüneceği belli. Altında gün
/// şeridi ve saat, kampüs noktaları, açıklama. Kaydet altta, başparmağın altında.
struct ClubEventComposer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: ClubEventDraft
    @State private var saving = false
    @State private var failure: String?
    @State private var showCalendar = false
    @State private var confirmDiscard = false
    @FocusState private var focus: Field?
    private let original: ClubEventDraft
    private let clubName: String
    private let accent: Color

    private enum Field { case title, placeNote, details }

    /// Gün şeridinde kaç gün: üç hafta. Daha ilerisi "Diğer"den.
    private static let stripDays = 21

    init(draft: ClubEventDraft, clubName: String, accent: Color) {
        _draft = State(initialValue: draft)
        original = draft
        self.clubName = clubName
        self.accent = accent
    }

    private var isNew: Bool { draft.id == nil }
    private var isDirty: Bool { draft != original }
    private var trimmedTitle: String { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Yeni etkinlik geçmişe kurulmaz; düzenlerken sunucu gibi bir saat pay var.
    private var timeIsPast: Bool {
        draft.startsAt < (isNew ? Date.now : Date.now.addingTimeInterval(-3600))
    }
    private var canSave: Bool { !saving && !trimmedTitle.isEmpty && !timeIsPast && isDirty }

    private var calendar: Calendar { Calendar.current }
    private var stripDates: [Date] {
        let bugun = calendar.startOfDay(for: .now)
        return (0..<Self.stripDays).compactMap { calendar.date(byAdding: .day, value: $0, to: bugun) }
    }
    /// Seçilen gün şeridin dışında mı (üç haftadan ileri).
    private var pickedBeyondStrip: Bool {
        guard let son = stripDates.last else { return false }
        return calendar.startOfDay(for: draft.startsAt) > son
    }
    private var placeName: String? { appState.places.first { $0.id == draft.placeID }?.name }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                    preview
                    whenSection
                    placeSection
                    detailsSection
                }
                .padding(BondTheme.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BondTheme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(isNew ? L10n.ClubEvents.newTitle : L10n.ClubEvents.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        if isDirty { confirmDiscard = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(isDirty)
            .confirmationDialog(L10n.ClubEvents.discardTitle, isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button(L10n.ClubEvents.discard, role: .destructive) { dismiss() }
                Button(L10n.ClubEvents.keepEditing, role: .cancel) {}
            }
            .sheet(isPresented: $showCalendar) { calendarSheet }
            .task {
                if appState.places.isEmpty { await appState.loadPlaces(silently: true) }
            }
            .task {
                // Sayfa yerine oturduktan sonra: yoksa klavye açılışla çakışıyor.
                guard isNew else { return }
                try? await Task.sleep(for: .milliseconds(450))
                focus = .title
            }
        }
    }

    // MARK: - Kart

    /// Kulüp sayfasındaki kartın aynısı; başlık doğrudan burada yazılıyor.
    private var preview: some View {
        HStack(alignment: .top, spacing: 14) {
            ClubEventDateBlock(date: draft.startsAt, accent: accent)
                .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: draft.startsAt)
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: clubName, color: accent)
                TextField(L10n.ClubEvents.titlePlaceholder, text: $draft.title, axis: .vertical)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .focused($focus, equals: .title)
                    .onChange(of: draft.title) { _, yeni in
                        // Çok satırlı alanda Return yeni satır açıyor; başlıkta
                        // satır yok, Return klavyeyi kapatsın.
                        if yeni.contains("\n") {
                            draft.title = yeni.replacingOccurrences(of: "\n", with: "")
                            focus = nil
                        } else if yeni.count > 80 {
                            draft.title = String(yeni.prefix(80))
                        }
                    }
                    .accessibilityIdentifier("event.title")
                Text([ClubEventFormat.when(draft.startsAt), ClubEvent.placeLabel(name: placeName, note: draft.placeNote)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: draft.startsAt)
            }
            Spacer(minLength: 0)
        }
        .padding(BondTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { focus = .title }
    }

    // MARK: - Ne zaman

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: L10n.ClubEvents.when)
                Spacer()
                Text(ClubEventFormat.fullDate(draft.startsAt))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BondTheme.ink)
                    .contentTransition(.opacity)
            }
            dayStrip
            HStack {
                Text(L10n.ClubEvents.time)
                    .font(.body)
                    .foregroundStyle(BondTheme.ink)
                Spacer()
                DatePicker(L10n.ClubEvents.time, selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.locale, L10n.appLocale)
                    .tint(accent)
                    .accessibilityIdentifier("event.time")
            }
            .padding(.leading, BondTheme.Space.md)
            .padding(.trailing, BondTheme.Space.sm)
            .frame(minHeight: 52)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if timeIsPast {
                Label(L10n.ClubEvents.timePast, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(BondTheme.burntOrangeText)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: timeIsPast)
    }

    private var dayStrip: some View {
        ScrollViewReader { kaydirici in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BondTheme.Space.sm) {
                    ForEach(stripDates, id: \.self) { gun in
                        dayTile(gun).id(gun)
                    }
                    otherDateTile.id("diger")
                }
                .padding(.horizontal, BondTheme.Space.lg)
            }
            .padding(.horizontal, -BondTheme.Space.lg)
            .onAppear {
                // Düzenlerken seçili gün görünsün.
                if pickedBeyondStrip {
                    kaydirici.scrollTo("diger", anchor: .trailing)
                } else if let secili = stripDates.first(where: { calendar.isDate($0, inSameDayAs: draft.startsAt) }) {
                    kaydirici.scrollTo(secili, anchor: .center)
                }
            }
        }
    }

    private func dayTile(_ gun: Date) -> some View {
        let secili = calendar.isDate(gun, inSameDayAs: draft.startsAt)
        return Button { selectDay(gun) } label: {
            VStack(spacing: 3) {
                Text(calendar.isDateInToday(gun) ? L10n.ClubEvents.todayShort : ClubEventFormat.weekdayShort(gun))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secili ? Color.white.opacity(0.85) : BondTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(ClubEventFormat.day(gun))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(secili ? Color.white : BondTheme.ink)
            }
            .frame(width: 52, height: 60)
            .background(secili ? accent : BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(ClubEventFormat.fullDate(gun))
        .accessibilityAddTraits(secili ? .isSelected : [])
    }

    /// Üç haftadan ilerisi: takvim. O günlerden biri seçiliyse burada görünür.
    private var otherDateTile: some View {
        Button { showCalendar = true } label: {
            VStack(spacing: 3) {
                if pickedBeyondStrip {
                    Text(ClubEventFormat.month(draft.startsAt))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text(ClubEventFormat.day(draft.startsAt))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                } else {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BondTheme.ink)
                    Text(L10n.ClubEvents.otherDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BondTheme.muted)
                }
            }
            .frame(width: 60, height: 60)
            .background(pickedBeyondStrip ? accent : BondTheme.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(L10n.ClubEvents.pickDate)
        .accessibilityAddTraits(pickedBeyondStrip ? .isSelected : [])
    }

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(L10n.ClubEvents.pickDate, selection: dayBinding,
                       in: calendar.startOfDay(for: .now)...Date.now.addingTimeInterval(364 * 24 * 3600),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.locale, L10n.appLocale)
                .padding(.horizontal, BondTheme.Space.md)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle(L10n.ClubEvents.pickDate)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.done) { showCalendar = false }
                    }
                }
        }
        .tint(accent)
        .presentationDetents([.medium, .large])
        .presentationBackground(BondTheme.paper)
    }

    /// Gün değişince saat aynı kalır.
    private func selectDay(_ gun: Date) {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { draft.startsAt = merged(day: gun, time: draft.startsAt) }
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { draft.startsAt },
            set: { draft.startsAt = merged(day: $0, time: draft.startsAt) }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { draft.startsAt },
            set: { draft.startsAt = merged(day: draft.startsAt, time: $0) }
        )
    }

    private func merged(day: Date, time: Date) -> Date {
        let saat = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: saat.hour ?? 19, minute: saat.minute ?? 0, second: 0, of: day) ?? day
    }

    // MARK: - Nerede

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.ClubEvents.place)
            if !appState.places.isEmpty {
                ScrollViewReader { kaydirici in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BondTheme.Space.sm) {
                            ForEach(appState.places) { yer in
                                placeChip(yer).id(yer.id)
                            }
                        }
                        .padding(.horizontal, BondTheme.Space.lg)
                    }
                    .padding(.horizontal, -BondTheme.Space.lg)
                    .onAppear {
                        if let secili = draft.placeID { kaydirici.scrollTo(secili, anchor: .center) }
                    }
                }
            }
            TextField(draft.placeID == nil ? L10n.ClubEvents.placeNotePlaceholder : L10n.ClubEvents.placeNoteExtraPlaceholder,
                      text: $draft.placeNote)
                .focused($focus, equals: .placeNote)
                .submitLabel(.next)
                .onSubmit { focus = .details }
                .onChange(of: draft.placeNote) { _, yeni in
                    if yeni.count > 80 { draft.placeNote = String(yeni.prefix(80)) }
                }
                .padding(.horizontal, BondTheme.Space.md)
                .frame(minHeight: 52)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("event.placeNote")
        }
    }

    private func placeChip(_ yer: CampusPlace) -> some View {
        let secili = draft.placeID == yer.id
        return Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : BondTheme.Motion.snappy) { draft.placeID = secili ? nil : yer.id }
        } label: {
            HStack(spacing: 6) {
                if secili {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(yer.name)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(secili ? Color.white : BondTheme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(secili ? accent : BondTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(secili ? .isSelected : [])
    }

    // MARK: - Açıklama

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: L10n.ClubEvents.details)
                Spacer()
                if draft.details.count >= 400 {
                    Text("\(draft.details.count)/500")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(draft.details.count >= 500 ? BondTheme.burntOrangeText : BondTheme.muted)
                }
            }
            TextField(L10n.ClubEvents.detailsPlaceholder, text: $draft.details, axis: .vertical)
                .lineLimit(4...12)
                .focused($focus, equals: .details)
                .onChange(of: draft.details) { _, yeni in
                    if yeni.count > 500 { draft.details = String(yeni.prefix(500)) }
                }
                .padding(BondTheme.Space.md)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("event.details")
        }
    }

    // MARK: - Kaydet

    private var saveBar: some View {
        VStack(spacing: BondTheme.Space.sm) {
            if let failure {
                Label(failure, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(BondTheme.burntOrangeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            Button { Task { await save() } } label: {
                ZStack {
                    if saving {
                        ProgressView().tint(.white)
                    } else {
                        Text(isNew ? L10n.ClubEvents.create : L10n.ClubEvents.saveChanges)
                    }
                }
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(accent.opacity(canSave || saving ? 1 : 0.35), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.pressable)
            .disabled(!canSave)
            .accessibilityIdentifier("event.save")
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.sm)
        .padding(.bottom, BondTheme.Space.sm)
        .background(BondTheme.paper)
        .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: failure)
    }

    private func save() async {
        guard canSave else { return }
        focus = nil
        saving = true
        defer { saving = false }
        failure = nil
        draft.title = trimmedTitle
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
