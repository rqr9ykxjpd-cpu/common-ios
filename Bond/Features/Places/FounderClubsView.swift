import SwiftUI

/// Kurucu paneli → Kulüpler: kapalılar dahil bütün kulüpler; aç, düzenle,
/// yönetici ata.
struct FounderClubsView: View {
    @Environment(AppState.self) private var appState
    @State private var clubs: [ClubAdminEntry] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var editing: ClubEditorRoute?

    var body: some View {
        Group {
            if loading, clubs.isEmpty {
                VStack(spacing: 0) { ForEach(0..<4, id: \.self) { _ in SkeletonRow() } }
                    .padding(.horizontal, BondTheme.Space.lg)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else if let failure, clubs.isEmpty {
                ScreenFailureView(message: failure) { Task { await load() } }
                    .padding(.horizontal, BondTheme.Space.lg)
            } else if clubs.isEmpty {
                AppEmptyState(systemImage: "person.3", title: L10n.ClubAdmin.emptyClubs,
                              message: L10n.ClubAdmin.emptyClubsBody, actionTitle: L10n.ClubAdmin.newClub) {
                    editing = ClubEditorRoute(clubID: nil)
                }
                .padding(BondTheme.Space.lg)
            } else {
                List(clubs) { kulup in
                    Button { editing = ClubEditorRoute(clubID: kulup.id) } label: { row(kulup) }
                        .buttonStyle(.plain)
                        .listRowBackground(BondTheme.paper)
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .navigationTitle(L10n.ClubAdmin.clubsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = ClubEditorRoute(clubID: nil) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L10n.ClubAdmin.newClub)
            }
        }
        .sheet(item: $editing, onDismiss: { Task { await load() } }) { rota in
            ClubEditorView(clubID: rota.clubID)
        }
        .task { await load() }
    }

    private func row(_ kulup: ClubAdminEntry) -> some View {
        HStack(spacing: BondTheme.Space.compact) {
            ClubLogoView(url: kulup.draft.logoURL, icon: kulup.draft.icon, accentHex: kulup.draft.accentHex, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kulup.draft.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if !kulup.draft.isActive {
                        Text(L10n.ClubAdmin.inactive.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(BondTheme.ink.opacity(0.08), in: Capsule())
                            .foregroundStyle(BondTheme.muted)
                    }
                }
                Text("\(L10n.ClubAdmin.memberCount(kulup.memberCount)) · \(L10n.ClubAdmin.managerCount(kulup.managerCount))")
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BondTheme.muted)
                .accessibilityHidden(true)
        }
        .foregroundStyle(BondTheme.ink)
        .opacity(kulup.draft.isActive ? 1 : 0.6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func load() async {
        failure = nil
        do { clubs = try await appState.fetchAdminClubs() }
        catch { failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.loadFailed) }
        loading = false
    }
}

struct ClubEditorRoute: Identifiable {
    let id = UUID()
    let clubID: UUID?
}

/// Kulübün üyeleri: yönetici ve kurucu görür, üye çıkarabilir. Yönetici başka
/// bir yöneticiyi çıkaramaz (sunucu da reddeder).
struct ClubPeopleView: View {
    let clubID: UUID
    let clubName: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var people: [ClubPerson] = []
    @State private var loading = true
    @State private var failure: String?
    @State private var pendingRemoval: ClubPerson?

    var body: some View {
        NavigationStack {
            Group {
                if loading, people.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if people.isEmpty {
                    AppEmptyState(systemImage: "person.2", title: L10n.ClubAdmin.membersEmpty)
                        .padding(BondTheme.Space.lg)
                } else {
                    List(people) { kisi in
                        HStack(spacing: BondTheme.Space.compact) {
                            SupportAvatar(url: kisi.avatarURL, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(kisi.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    if kisi.isManager {
                                        Text(L10n.ClubAdmin.managerChip)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(BondTheme.ink.opacity(0.08), in: Capsule())
                                            .foregroundStyle(BondTheme.ink)
                                    }
                                }
                                if let ad = kisi.username {
                                    Text("@\(ad)").font(.caption).foregroundStyle(BondTheme.muted)
                                }
                            }
                            Spacer(minLength: 0)
                            if appState.isFounder || !kisi.isManager {
                                Menu {
                                    Button(L10n.ClubAdmin.removeMember, role: .destructive) {
                                        pendingRemoval = kisi
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").foregroundStyle(BondTheme.muted)
                                }
                            }
                        }
                        .listRowBackground(BondTheme.paper)
                    }
                    .listStyle(.plain)
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle("\(clubName) · \(L10n.ClubAdmin.members)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.close) { dismiss() } }
            }
            .overlay(alignment: .bottom) {
                if let failure {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.burntOrangeText)
                        .padding()
                }
            }
            .confirmationDialog(
                pendingRemoval.map { L10n.ClubAdmin.removeMemberConfirm($0.name) } ?? "",
                isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                titleVisibility: .visible,
                presenting: pendingRemoval
            ) { kisi in
                Button(L10n.ClubAdmin.removeMember, role: .destructive) {
                    Task { await remove(kisi) }
                }
            } message: { _ in
                Text(L10n.ClubAdmin.removeMemberHint)
            }
            .task { await load() }
        }
    }

    private func load() async {
        failure = nil
        do { people = try await appState.fetchClubPeople(clubID) }
        catch { failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.loadFailed) }
        loading = false
    }

    private func remove(_ kisi: ClubPerson) async {
        do {
            try await appState.removeClubMember(clubID, userID: kisi.id)
            withAnimation(BondTheme.Motion.smooth) { people.removeAll { $0.id == kisi.id } }
            Haptics.success()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.ClubAdmin.saveFailed)
        }
    }
}
