import SwiftUI

/// Common hesabı → bir kişinin kartı → ⋯ → "Kulüp hesabı yap". Kişinin
/// hesabını seçilen kulübün resmi hesabı yapar ya da bağı kaldırır.
struct ClubAccountSheet: View {
    let person: StudentProfile

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var clubs: [ClubAdminEntry] = []
    /// Kişinin şu an bağlı olduğu kulüp.
    @State private var current: UUID?
    @State private var loaded = false
    @State private var working = false
    @State private var pending: ClubAdminEntry?
    @State private var failure: String?

    private var personLabel: String { person.name }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.ClubAdmin.clubAccountHint)
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
                if current != nil {
                    Section {
                        Button(L10n.ClubAdmin.removeClubAccount, role: .destructive) {
                            Task { await remove() }
                        }
                        .disabled(working)
                    }
                }
            }
            .navigationTitle(L10n.ClubAdmin.clubAccountTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .confirmationDialog(
                pending.map { L10n.ClubAdmin.clubAccountConfirm(personLabel, $0.draft.name) } ?? "",
                isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                titleVisibility: .visible
            ) {
                Button(L10n.ClubAdmin.makeClubAccount) {
                    if let club = pending { Task { await make(club) } }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            }
            .task { await load() }
        }
    }

    private func clubRow(_ club: ClubAdminEntry) -> some View {
        let secili = club.id == current
        return Button {
            if !secili { pending = club }
        } label: {
            HStack(spacing: BondTheme.Space.compact) {
                ClubLogoView(url: club.draft.logoURL, icon: club.draft.icon, accentHex: club.draft.accentHex, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.draft.name)
                        .foregroundStyle(.primary)
                    if secili {
                        Text(L10n.ClubAdmin.clubAccountCurrent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !club.draft.isActive {
                        Text(L10n.ClubAdmin.inactive)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if secili {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BondTheme.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(working)
        .accessibilityAddTraits(secili ? .isSelected : [])
    }

    private func load() async {
        do {
            async let liste = appState.fetchAdminClubs()
            async let bag = appState.clubAccountClub(of: person.id)
            clubs = try await liste
            current = try await bag
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
        loaded = true
    }

    private func make(_ club: ClubAdminEntry) async {
        working = true
        defer { working = false; pending = nil }
        do {
            let ad = try await appState.makeClubAccount(person.id, clubID: club.id)
            current = club.id
            failure = nil
            Haptics.success()
            appState.show(L10n.ClubAdmin.clubAccountDone(ad))
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }

    private func remove() async {
        working = true
        defer { working = false }
        do {
            try await appState.removeClubAccount(person.id)
            current = nil
            failure = nil
            Haptics.success()
            appState.show(L10n.ClubAdmin.clubAccountRemoved)
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }
}
