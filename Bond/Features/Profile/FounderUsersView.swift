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
                List {
                    // Yeşil nokta: son 8 dakikada uygulamayı açık tutanlar.
                    Section {
                        ForEach(users) { user in
                            Button { actionTarget = user } label: { row(user) }
                                .buttonStyle(.plain)
                                .listRowBackground(BondTheme.paper)
                        }
                    } header: {
                        let cevrimici = users.filter(\.isOnline).count
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(cevrimici == 0 ? BondTheme.muted.opacity(0.4) : Color.green)
                                    .frame(width: 8, height: 8)
                                Text(cevrimici == 0 ? L10n.Support.usersOnlineNone : L10n.Support.usersOnline(cevrimici))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(cevrimici == 0 ? BondTheme.muted : BondTheme.ink)
                            }
                            Label(L10n.Support.pushCount(users.filter(\.hasPush).count), systemImage: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(BondTheme.muted)
                        }
                        .textCase(nil)
                        .accessibilityElement(children: .combine)
                    }
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
        .sheet(item: $profileRoute) { profil in
            NavigationStack {
                SocialPersonDetailView(profile: profil, place: nil, showsClose: true)
            }
        }
    }

    private func row(_ user: FounderUser) -> some View {
        HStack(spacing: BondTheme.Space.compact) {
            ProfileMedia(url: user.avatarURL, data: nil, assetName: user.avatarAssetName)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .opacity(user.isActive ? 1 : 0.45)
                .overlay(alignment: .bottomTrailing) {
                    if user.isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(BondTheme.paper, lineWidth: 2))
                            .accessibilityLabel(L10n.Support.online)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.name).font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .layoutPriority(1)
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
                            .foregroundStyle(BondTheme.burntOrangeText)
                    }
                    if user.eduVerified {
                        EduStudentChip()
                    } else if user.eduExempt, user.badge == .none {
                        Text(L10n.Support.eduExempt.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(BondTheme.ink.opacity(0.08), in: Capsule())
                            .foregroundStyle(BondTheme.muted)
                    }
                    if !user.isActive {
                        Text(L10n.Board.userFrozen.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(BondTheme.ink.opacity(0.1), in: Capsule())
                    }
                }
                if !bolumSatiri(user).isEmpty {
                    Text(bolumSatiri(user))
                        .font(.caption)
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(1)
                }
                // Etkinlik ve bildirim ayrı satırda: tek satırda "Son aktif…" kesiliyordu.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { etkinlik(user); bildirim(user) }
                    VStack(alignment: .leading, spacing: 2) { etkinlik(user); bildirim(user) }
                }
                .font(.caption)
            }
            Spacer()
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(BondTheme.muted)
        }
        .foregroundStyle(BondTheme.ink)
        .contentShape(Rectangle())
    }

    private func bolumSatiri(_ user: FounderUser) -> String {
        [user.department, AcademicYear.display(user.academicYear)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func etkinlik(_ user: FounderUser) -> some View {
        Text(user.isOnline ? L10n.Support.online : L10n.Board.userActive(user.lastActiveAt.relativeTurkish))
            .foregroundStyle(user.isOnline ? Color.green : BondTheme.muted)
            .lineLimit(1)
    }

    private func bildirim(_ user: FounderUser) -> some View {
        HStack(spacing: 3) {
            Image(systemName: user.hasPush ? "bell.fill" : "bell.slash")
            Text(user.hasPush ? L10n.Support.pushOn : L10n.Support.pushOff)
        }
        .foregroundStyle(BondTheme.muted)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func userMeta(_ user: FounderUser) -> String {
        let bolum = [user.department, AcademicYear.display(user.academicYear)].filter { !$0.isEmpty }.joined(separator: " · ")
        return [bolum, L10n.Board.userActive(user.lastActiveAt.relativeTurkish)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    @ViewBuilder
    private func actions(for user: FounderUser) -> some View {
        Button(L10n.Support.openProfile) { profileRoute = studentProfile(user) }
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
            if !user.eduVerified {
                Button(user.eduExempt ? L10n.Support.removeExempt : L10n.Support.makeExempt) {
                    Task { await setEduExempt(user, !user.eduExempt) }
                }
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

    private func setEduExempt(_ user: FounderUser, _ exempt: Bool) async {
        do {
            let yeni = try await appState.founderSetEduExempt(user.id, exempt: exempt)
            update(user.id) { $0.eduExempt = yeni }
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

    /// Kişi kartı ayrıntıları (bio, fotoğraflar) kendisi çekiyor; yaş kartta görünmüyor.
    private func studentProfile(_ user: FounderUser) -> StudentProfile {
        StudentProfile(id: user.id, name: user.name, age: 18, university: "", department: user.department,
                       year: user.academicYear, bio: "", interests: [], imageURL: user.avatarURL,
                       imageAssetName: user.avatarAssetName, isVerified: user.isVerified, badge: user.badge)
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
