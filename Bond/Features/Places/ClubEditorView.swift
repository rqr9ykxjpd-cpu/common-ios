import PhotosUI
import SwiftUI

/// Kulüp aç / düzenle. Kurucu her alanı ve yöneticileri değiştirir; yönetici
/// kendi kulübünün açıklamasını, etkinliğini, yerini, görünümünü, logosunu ve
/// iletişimini. Adı ve açık/kapalı durumu kurucuda; sunucu da böyle uyguluyor.
struct ClubEditorView: View {
    let clubID: UUID?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ClubDraft()
    @State private var loaded = false
    @State private var saving = false
    @State private var failure: String?
    @State private var logoItem: PhotosPickerItem?
    @State private var uploadingLogo = false
    @State private var managers: [ClubPerson] = []
    @State private var showManagerPicker = false
    /// Kulübün paletin dışındaki kendi rengi/simgesi: ilk sırada durur, kaybolmaz.
    @State private var ownColor: String?
    @State private var ownIcon: String?

    private var founder: Bool { appState.isFounder }
    private var isNew: Bool { draft.id == nil }
    private var icons: [String] { (ownIcon.map { [$0] } ?? []) + ClubPalette.icons }
    private var colors: [String] { (ownColor.map { [$0] } ?? []) + ClubPalette.colors }
    private var canSave: Bool {
        loaded && !saving && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { kaydirici in
                Form {
                    if loaded {
                        // Hata en üstte: Kaydet de yukarıda, göz oraya bakıyor.
                        if let failure {
                            Section {
                                Label(failure, systemImage: "exclamationmark.circle")
                                    .font(.footnote)
                                    .foregroundStyle(BondTheme.burntOrangeText)
                            }
                            .id("hata")
                        }
                        identitySection
                        eventSection
                        lookSection
                        contactSection
                        if founder { activeSection }
                        if founder, !isNew { managersSection }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: failure) { _, yeni in
                    guard yeni != nil else { return }
                    Haptics.warning()
                    withAnimation(BondTheme.Motion.smooth) { kaydirici.scrollTo("hata", anchor: .top) }
                }
            }
            .navigationTitle(isNew ? L10n.ClubAdmin.newClub : L10n.ClubAdmin.editClub)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button(L10n.ClubAdmin.save) { Task { await save() } }
                            .disabled(!canSave)
                            .accessibilityIdentifier("club.save")
                    }
                }
            }
            .task { await load() }
            .onChange(of: logoItem) { _, item in
                guard item != nil else { return }
                Task { await uploadLogo(item) }
            }
            .sheet(isPresented: $showManagerPicker) {
                ClubManagerPicker(exclude: Set(managers.map(\.id))) { kisi in
                    Task { await setManager(kisi, true) }
                }
            }
        }
    }

    // MARK: - Bölümler

    private var identitySection: some View {
        Section {
            if let id = draft.id {
                HStack(spacing: BondTheme.Space.md) {
                    ClubLogoView(url: draft.logoURL, icon: draft.icon, accentHex: draft.accentHex, size: 56)
                    PhotosPicker(selection: $logoItem, matching: .images) {
                        Text(draft.logoURL == nil ? L10n.ClubAdmin.logoPick : L10n.ClubAdmin.logoChange)
                    }
                    .disabled(uploadingLogo)
                    Spacer(minLength: 0)
                    if uploadingLogo { ProgressView() }
                }
                .id(id)
            }
            TextField(L10n.ClubAdmin.namePlaceholder, text: $draft.name)
                .font(.headline)
                .disabled(!founder && !isNew)
                .foregroundStyle(!founder && !isNew ? BondTheme.muted : BondTheme.ink)
            TextField(L10n.ClubAdmin.summaryPlaceholder, text: $draft.summary, axis: .vertical)
                .lineLimit(3...6)
        } footer: {
            if isNew {
                Text(L10n.ClubAdmin.logoAfterSave)
            } else if !founder {
                Text(L10n.ClubAdmin.managerNote)
            }
        }
    }

    private var eventSection: some View {
        Section(L10n.ClubAdmin.nextEvent) {
            TextField(L10n.ClubAdmin.nextEventPlaceholder, text: $draft.nextEvent)
            Picker(L10n.ClubAdmin.place, selection: $draft.placeID) {
                Text(L10n.ClubAdmin.noPlace).tag(UUID?.none)
                ForEach(appState.places) { yer in
                    Text(yer.name).tag(Optional(yer.id))
                }
            }
        }
    }

    private var lookSection: some View {
        Section(L10n.ClubAdmin.look) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
                ForEach(icons, id: \.self) { simge in
                    Button { draft.icon = simge } label: {
                        Image(systemName: simge)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(draft.icon == simge ? BondTheme.paper : BondTheme.ink)
                            .background(draft.icon == simge ? Color(hex: draft.accentHex) : BondTheme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(simge)
                    .accessibilityAddTraits(draft.icon == simge ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
            // Tek satır: kulübün kendi rengi varsa dokuz daire de sığıyor.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: colors.count), spacing: 10) {
                ForEach(colors, id: \.self) { renk in
                    Button { draft.accentHex = renk } label: {
                        Circle()
                            .fill(Color(hex: renk))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if draft.accentHex.uppercased() == renk.uppercased() {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.ClubAdmin.color)
                    .accessibilityAddTraits(draft.accentHex.uppercased() == renk.uppercased() ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var contactSection: some View {
        Section(L10n.ClubAdmin.contact) {
            TextField(L10n.ClubAdmin.instagramPlaceholder, text: $draft.instagram)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField(L10n.ClubAdmin.emailPlaceholder, text: $draft.contactEmail)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var activeSection: some View {
        Section {
            Toggle(L10n.ClubAdmin.active, isOn: $draft.isActive)
                .tint(BondTheme.burntOrange)
        } footer: {
            Text(L10n.ClubAdmin.activeHint)
        }
    }

    private var managersSection: some View {
        Section {
            ForEach(managers) { kisi in
                HStack(spacing: BondTheme.Space.compact) {
                    SupportAvatar(url: kisi.avatarURL, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kisi.name).font(.subheadline.weight(.semibold))
                        if let ad = kisi.username { Text("@\(ad)").font(.caption).foregroundStyle(BondTheme.muted) }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(L10n.ClubAdmin.removeManager, role: .destructive) {
                            Task { await setManager(kisi.id, false) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(BondTheme.muted)
                    }
                }
            }
            Button {
                showManagerPicker = true
            } label: {
                Label(L10n.ClubAdmin.addManager, systemImage: "person.badge.plus")
            }
        } header: {
            Text(L10n.ClubAdmin.managers)
        } footer: {
            Text(L10n.ClubAdmin.managersHint)
        }
    }

    // MARK: - İşler

    private func load() async {
        guard !loaded else { return }
        if let clubID {
            if founder, let kayit = try? await appState.fetchAdminClubs().first(where: { $0.id == clubID }) {
                draft = kayit.draft
            } else if let club = appState.clubs.first(where: { $0.id == clubID }) {
                let ek = appState.clubExtras[clubID]
                draft = ClubDraft(id: club.id, name: club.name, summary: club.summary, icon: club.icon,
                                  nextEvent: club.nextEvent, placeID: club.meetingPlace?.id,
                                  accentHex: club.accentHex, instagram: ek?.instagram ?? "",
                                  contactEmail: ek?.contactEmail ?? "", isActive: true, logoURL: ek?.logoURL)
            }
            if founder { await loadManagers() }
        }
        let renk = draft.accentHex.uppercased()
        if !ClubPalette.colors.contains(renk) { ownColor = renk }
        if !ClubPalette.icons.contains(draft.icon) { ownIcon = draft.icon }
        loaded = true
    }

    private func save() async {
        guard canSave else { failure = L10n.ClubAdmin.nameRequired; return }
        draft.instagram = Self.instagramHandle(draft.instagram)
        draft.contactEmail = draft.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.instagram.isEmpty, draft.instagram.range(of: #"^[A-Za-z0-9._]{1,30}$"#, options: .regularExpression) == nil {
            failure = L10n.ClubAdmin.instagramInvalid
            return
        }
        if !draft.contactEmail.isEmpty, draft.contactEmail.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) == nil {
            failure = L10n.ClubAdmin.emailInvalid
            return
        }
        saving = true
        defer { saving = false }
        failure = nil
        do {
            let yeniMi = draft.id == nil
            let id = try await appState.saveClub(draft)
            Haptics.success()
            appState.show(L10n.ClubAdmin.saved)
            if yeniMi {
                // Açık kalsın: logo ve yönetici ancak kayıttan sonra eklenebiliyor.
                draft.id = id
            } else {
                dismiss()
            }
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }

    /// "@kulup", "instagram.com/kulup/" ya da tam bağlantı: hepsi "kulup" olur.
    static func instagramHandle(_ girdi: String) -> String {
        var ad = girdi.trimmingCharacters(in: .whitespacesAndNewlines)
        if let aralik = ad.range(of: "instagram.com/", options: .caseInsensitive) {
            ad = String(ad[aralik.upperBound...])
            ad = String(ad.prefix { $0 != "/" && $0 != "?" && $0 != "#" })
        }
        while ad.hasPrefix("@") { ad.removeFirst() }
        return ad
    }

    private func uploadLogo(_ item: PhotosPickerItem?) async {
        guard let item, let id = draft.id else { return }
        uploadingLogo = true
        defer { uploadingLogo = false; logoItem = nil }
        do {
            guard let veri = try await item.loadImageData() else { return }
            draft.logoURL = try await appState.uploadClubLogo(id, imageData: veri)
            Haptics.success()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }

    private func loadManagers() async {
        guard let id = draft.id ?? clubID else { return }
        managers = ((try? await appState.fetchClubPeople(id)) ?? []).filter(\.isManager)
    }

    private func setManager(_ userID: UUID, _ acik: Bool) async {
        guard let id = draft.id else { return }
        do {
            _ = try await appState.setClubManager(id, userID: userID, enabled: acik)
            Haptics.success()
            await loadManagers()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }
}

/// Kurucu: yönetici olacak öğrenciyi seç (Kullanıcılar listesiyle aynı arama).
struct ClubManagerPicker: View {
    let exclude: Set<UUID>
    let onPick: (UUID) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var users: [FounderUser] = []

    var body: some View {
        NavigationStack {
            List(users.filter { !exclude.contains($0.id) && $0.isActive }) { kisi in
                Button {
                    onPick(kisi.id)
                    dismiss()
                } label: {
                    HStack(spacing: BondTheme.Space.compact) {
                        SupportAvatar(url: kisi.avatarURL, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kisi.name).font(.subheadline.weight(.semibold))
                            Text(kisi.department).font(.caption).foregroundStyle(BondTheme.muted)
                        }
                    }
                    .foregroundStyle(BondTheme.ink)
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: L10n.ClubAdmin.managerSearch)
            .navigationTitle(L10n.ClubAdmin.addManager)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.close) { dismiss() } }
            }
            .task(id: search) {
                try? await Task.sleep(for: .milliseconds(search.isEmpty ? 0 : 300))
                users = (try? await appState.fetchFounderUsers(search: search.trimmingCharacters(in: .whitespaces))) ?? []
            }
        }
    }
}

/// Kulübün yüzü: logo varsa logo, yoksa renkli daire içinde simge.
struct ClubLogoView: View {
    let url: URL?
    let icon: String
    let accentHex: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url {
                ProfileMedia(url: url, data: nil, assetName: nil)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else {
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(hex: accentHex))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: accentHex).opacity(0.14), in: Circle())
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
