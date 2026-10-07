import SwiftUI

/// Common hesabı → bir kişinin kartı → ⋯ → "Kulüp yöneticisi yap". Dokunulan
/// kulübün yöneticiliği açılır ya da kapanır. Yönetici kendi profilinden
/// kulübün hesabına geçer; hesap ilk geçişte sunucuda açılır.
struct ClubManagerSheet: View {
    let person: StudentProfile

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var clubs: [ClubAdminEntry] = []
    @State private var managed: Set<UUID> = []
    @State private var loaded = false
    @State private var working: UUID?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.ClubSwitch.managerHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(BondTheme.burntOrangeText)
                    }
                }
                Section {
                    if !loaded {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if clubs.isEmpty {
                        Text(L10n.ClubAdmin.emptyClubs).foregroundStyle(.secondary)
                    }
                    ForEach(clubs) { club in
                        clubRow(club)
                    }
                }
            }
            .navigationTitle(L10n.ClubSwitch.managerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func clubRow(_ club: ClubAdminEntry) -> some View {
        let yonetici = managed.contains(club.id)
        return Button {
            Task { await toggle(club, enabled: !yonetici) }
        } label: {
            HStack(spacing: BondTheme.Space.compact) {
                ClubLogoView(url: club.draft.logoURL, icon: club.draft.icon, accentHex: club.draft.accentHex, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.draft.name)
                        .foregroundStyle(.primary)
                    if yonetici {
                        Text(L10n.ClubSwitch.managerOn)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !club.draft.isActive {
                        Text(L10n.ClubAdmin.inactive)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if working == club.id {
                    ProgressView()
                } else {
                    Image(systemName: yonetici ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(yonetici ? BondTheme.ink : BondTheme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(working != nil)
        .accessibilityAddTraits(yonetici ? .isSelected : [])
    }

    private func load() async {
        do {
            async let liste = appState.fetchAdminClubs()
            async let yonettikleri = appState.managedClubs(of: person.id)
            clubs = try await liste
            managed = try await yonettikleri
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
        loaded = true
    }

    private func toggle(_ club: ClubAdminEntry, enabled: Bool) async {
        working = club.id
        defer { working = nil }
        do {
            let simdi = try await appState.setClubManager(club.id, userID: person.id, enabled: enabled)
            if simdi { managed.insert(club.id) } else { managed.remove(club.id) }
            failure = nil
            Haptics.success()
            appState.show(simdi
                          ? L10n.ClubSwitch.managerAdded(person.name, club.draft.name)
                          : L10n.ClubSwitch.managerRemoved(club.draft.name))
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }
}
