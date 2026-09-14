import SwiftUI

/// Kurucu: kullanıcı listesi + işlemler (plan hediye, moderatör, dondur).
/// Sunucu her işlemde rozeti kontrol eder; burası yalnız arayüz.
struct FounderUsersView: View {
    @Environment(AppState.self) private var appState
    @State private var users: [FounderUser] = []
    @State private var search = ""
    @State private var isLoading = true
    @State private var failure: String?
    @State private var actionTarget: FounderUser?
    @State private var freezeTarget: FounderUser?
    @State private var toast: String?
    @State private var profileRoute: StudentProfile?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 0) { ForEach(0..<6, id: \.self) { _ in SkeletonRow() } }
                    .padding(.horizontal, BondTheme.Space.lg)
            } else if let failure {
                ScreenFailureView(message: failure) { Task { await load() } }
                    .padding(.horizontal, BondTheme.Space.lg)
            } else if users.isEmpty {
                ContentUnavailableView(L10n.Board.usersEmpty, systemImage: "person.slash")
            } else {
                List(users) { user in
                    Button { actionTarget = user } label: { row(user) }
                        .buttonStyle(.plain)
                        .listRowBackground(BondTheme.paper)
                }
                .listStyle(.plain)
            }
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .navigationTitle(L10n.Board.users)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: L10n.Board.usersSearch)
        .task(id: search) {
            try? await Task.sleep(for: .milliseconds(search.isEmpty ? 0 : 300))
            await load()
        }
        .confirmationDialog(actionTarget?.name ?? "", isPresented: Binding(
            get: { actionTarget != nil }, set: { if !$0 { actionTarget = nil } }
        ), titleVisibility: .visible, presenting: actionTarget) { user in
            actions(for: user)
        } message: { user in
            Text(userMeta(user))
        }
        .confirmationDialog(L10n.Board.freeze, isPresented: Binding(
            get: { freezeTarget != nil }, set: { if !$0 { freezeTarget = nil } }
        ), titleVisibility: .visible, presenting: freezeTarget) { user in
            Button(L10n.Board.freeze, role: .destructive) { Task { await setActive(user, false) } }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: { user in
            Text(L10n.Board.freezeConfirm(user.name))
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BondTheme.paper)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(BondTheme.ink, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toast)
    }

    private func row(_ user: FounderUser) -> some View {
        HStack(spacing: BondTheme.Space.compact) {
            ProfileMedia(url: user.avatarURL, data: nil, assetName: user.avatarAssetName)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .opacity(user.isActive ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.name).font(.subheadline.weight(.semibold))
                    if user.badge != .none, let icon = user.badge.systemImage {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(user.badge == .founder ? BondTheme.ember : BondTheme.icon)
                    }
                    if user.plan != .free {
                        Text(user.plan.title.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(BondTheme.burntOrange.opacity(0.15), in: Capsule())
                            .foregroundStyle(BondTheme.burntOrange)
                    }
                    if !user.isActive {
                        Text(L10n.Board.userFrozen.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(BondTheme.ink.opacity(0.1), in: Capsule())
                    }
                }
                Text(userMeta(user))
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(BondTheme.muted)
        }
        .foregroundStyle(BondTheme.ink)
        .contentShape(Rectangle())
    }

    private func userMeta(_ user: FounderUser) -> String {
        let bolum = [user.department, AcademicYear.display(user.academicYear)].filter { !$0.isEmpty }.joined(separator: " · ")
        return [bolum, L10n.Board.userActive(user.lastActiveAt.relativeTurkish)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder
    private func actions(for user: FounderUser) -> some View {
        if user.badge != .founder {
            Button(L10n.Board.giftPlus30) { Task { await grant(user, .plus, days: 30) } }
            Button(L10n.Board.giftPro30) { Task { await grant(user, .pro, days: 30) } }
            Button(L10n.Board.giftProForever) { Task { await grant(user, .pro, days: nil) } }
            if user.plan != .free {
                Button(L10n.Board.removeGift) { Task { await grant(user, .free, days: nil) } }
            }
            Button(user.badge == .moderator ? L10n.Board.removeModerator : L10n.Board.makeModerator) {
                Task { await setModerator(user, user.badge != .moderator) }
            }
            if user.isActive {
                Button(L10n.Board.freeze, role: .destructive) { freezeTarget = user }
            } else {
                Button(L10n.Board.unfreeze) { Task { await setActive(user, true) } }
            }
        }
        Button(L10n.Common.cancel, role: .cancel) {}
    }

    private func load() async {
        failure = nil
        if users.isEmpty { isLoading = true }
        do { users = try await appState.fetchFounderUsers(search: search.trimmed) }
        catch { failure = UserFacingError.message(error, fallback: L10n.Board.founderActionFailed) }
        isLoading = false
    }

    private func grant(_ user: FounderUser, _ plan: SubscriptionTier, days: Int?) async {
        do {
            let yeni = try await appState.founderGrantPlan(user.id, plan: plan, days: days)
            update(user.id) { $0.plan = yeni }
            show(L10n.Board.userDone)
        } catch { show(UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)) }
    }

    private func setModerator(_ user: FounderUser, _ enabled: Bool) async {
        do {
            let yeni = try await appState.founderSetModerator(user.id, enabled: enabled)
            update(user.id) { $0.badge = yeni }
            show(L10n.Board.userDone)
        } catch { show(UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)) }
    }

    private func setActive(_ user: FounderUser, _ active: Bool) async {
        do {
            let yeni = try await appState.founderSetActive(user.id, active: active)
            update(user.id) { $0.isActive = yeni }
            show(L10n.Board.userDone)
        } catch { show(UserFacingError.message(error, fallback: L10n.Board.founderActionFailed)) }
    }

    private func update(_ id: UUID, _ change: (inout FounderUser) -> Void) {
        guard let i = users.firstIndex(where: { $0.id == id }) else { return }
        change(&users[i])
    }

    private func show(_ text: String) {
        toast = text
        Haptics.impact(.light)
        Task { try? await Task.sleep(for: .seconds(2)); if toast == text { toast = nil } }
    }
}
