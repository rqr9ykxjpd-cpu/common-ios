import SwiftUI

/// Profil içeriğinden ayrılmış, sistem `List` ve `Section` yapısını kullanan ayarlar.
struct ProfileSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showCardPreview = false
    @State private var showSaved = false
    @State private var showVisits = false
    @State private var showPaywall = false
    @State private var showBlocked = false
    @State private var showModeration = false
    @State private var showAdmirers = false
    @State private var showMeetingRequests = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false

    private static let supportURL = URL(
        string: "mailto:220207018@yalova.edu.tr?subject=Common%20destek"
    )

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            List {
                Section(L10n.Profile.yourAccount) {
                    settingsButton(
                        icon: "rectangle.portrait.on.rectangle.portrait.angled",
                        title: L10n.Profile.cardHow,
                        detail: L10n.Profile.cardHowHint
                    ) {
                        showCardPreview = true
                    }

                    if appState.isModerator {
                        settingsButton(
                            icon: appState.pendingReports.isEmpty ? "shield" : "shield.fill",
                            title: L10n.Profile.reports,
                            detail: appState.pendingReports.isEmpty
                                ? L10n.Profile.reportsHint
                                : L10n.Profile.reportsWaiting(appState.pendingReports.count),
                            badge: appState.pendingReports.count
                        ) {
                            showModeration = true
                        }
                    }

                    // Yalnızca kurucuda. Moderatör rozetli biri bunu görmüyor;
                    // sunucudaki `who_liked_me` de zaten yalnızca kurucuya açık.
                    if appState.isFounder {
                        settingsButton(
                            icon: "heart.text.square",
                            title: L10n.Profile.admirers,
                            detail: L10n.Profile.admirersHint,
                            badge: appState.admirers.count
                        ) {
                            showAdmirers = true
                        }
                    }

                    settingsButton(
                        icon: "bookmark",
                        title: L10n.Profile.saved,
                        detail: L10n.Profile.savedHint
                    ) {
                        showSaved = true
                    }

                    settingsButton(
                        icon: appState.tier.canSeeProfileVisitors ? "eye" : "lock.fill",
                        title: L10n.Profile.visitors,
                        detail: L10n.Profile.visitorsHint,
                        trailing: appState.tier.canSeeProfileVisitors
                            ? (appState.profileVisits.isEmpty ? nil : "\(appState.profileVisits.count)")
                            : L10n.Tier.plus
                    ) {
                        if appState.tier.canSeeProfileVisitors {
                            showVisits = true
                        } else {
                            showPaywall = true
                        }
                    }

                    settingsButton(
                        icon: "cup.and.saucer",
                        title: L10n.Profile.meetings,
                        detail: L10n.Profile.meetingsHint,
                        badge: appState.pendingIncomingMeetingRequestCount
                    ) {
                        showMeetingRequests = true
                    }
                }

                Section(L10n.Profile.appearanceSection) {
                    Picker(L10n.Profile.appearance, selection: $state.appearance) {
                        ForEach(AppState.Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section(L10n.Profile.privacy) {
                    // Engelleme menüde şikayetin hemen yanında; yanlışlıkla
                    // basmak kolay ve şu ana kadar geri dönüşü yoktu.
                    settingsButton(
                        icon: "hand.raised",
                        title: L10n.Profile.blocked,
                        detail: L10n.Profile.blockedHint
                    ) {
                        showBlocked = true
                    }

                    if appState.tier.hasGhostMode {
                        Toggle(isOn: Binding(
                            get: { appState.ghostMode },
                            set: { appState.setGhostMode($0) }
                        )) {
                            settingsLabel(
                                icon: "eye.slash",
                                title: L10n.Profile.ghost,
                                detail: appState.ghostMode
                                    ? L10n.Profile.ghostOnDetail
                                    : L10n.Common.off
                            )
                        }
                    } else {
                        settingsButton(
                            icon: "lock.fill",
                            title: L10n.Profile.ghost,
                            detail: L10n.Profile.ghostOffDetail,
                            trailing: L10n.Tier.pro
                        ) {
                            showPaywall = true
                        }
                    }
                }

                Section {
                    settingsButton(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: L10n.Profile.signOut,
                        detail: L10n.Profile.signOutHint,
                        disabled: appState.isAccountActionInProgress
                    ) {
                        showSignOutAlert = true
                    }

                    settingsButton(
                        icon: "trash",
                        title: L10n.Profile.deletePermanent,
                        detail: L10n.Profile.irreversible,
                        destructive: true,
                        disabled: appState.isAccountActionInProgress
                    ) {
                        showDeleteAccountAlert = true
                    }

                    if appState.isAccountActionInProgress {
                        HStack(spacing: BondTheme.Space.sm) {
                            ProgressView()
                            Text(L10n.Profile.accountBusy)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(L10n.Profile.aboutSection) {
                    settingsButton(
                        icon: "doc.text",
                        title: L10n.Legal.terms,
                        detail: L10n.Profile.termsHint
                    ) {
                        showTerms = true
                    }

                    settingsButton(
                        icon: "hand.raised",
                        title: L10n.Legal.privacy,
                        detail: L10n.Profile.privacyHint
                    ) {
                        showPrivacy = true
                    }

                    if let supportURL = Self.supportURL {
                        Link(destination: supportURL) {
                            settingsLabel(
                                icon: "envelope",
                                title: L10n.Profile.support,
                                detail: L10n.Profile.supportHint
                            )
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.Profile.moreSettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
#if DEBUG
            .onAppear {
                if appState.opensCardPreview { showCardPreview = true }
                if appState.opensModeration { showModeration = true }
            }
#endif
            .task(id: appState.myBadge) {
                if appState.isModerator {
                    await appState.loadReports()
                }
                if appState.isFounder {
                    await appState.loadAdmirers()
                }
            }
            .sheet(isPresented: $showCardPreview) {
                OwnCardPreviewView()
            }
            .sheet(isPresented: $showAdmirers) {
                AdmirersView()
            }
            .sheet(isPresented: $showSaved) {
                ProfileSavedPostsView()
            }
            .sheet(isPresented: $showVisits) {
                ProfileVisitorsView()
            }
            .sheet(isPresented: $showBlocked) {
                NavigationStack { BlockedProfilesView() }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showModeration) {
                ModerationView()
            }
            .sheet(isPresented: $showMeetingRequests) {
                MeetingRequestsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    LegalTextView(
                        title: LegalDocumentRoute.kosullar.title,
                        blocks: LegalDocumentRoute.kosullar.blocks
                    )
                }
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    LegalTextView(
                        title: LegalDocumentRoute.gizlilik.title,
                        blocks: LegalDocumentRoute.gizlilik.blocks
                    )
                }
            }
            .alert(L10n.Profile.signOutConfirm, isPresented: $showSignOutAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Profile.signOut, role: .destructive) {
                    Task { await appState.signOut() }
                }
            } message: {
                Text(L10n.Profile.signOutBody)
            }
            .alert(L10n.Profile.deleteConfirm, isPresented: $showDeleteAccountAlert) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Profile.deleteAccount, role: .destructive) {
                    Task { await appState.deleteAccount() }
                }
            } message: {
                Text(L10n.Profile.deleteBody)
            }
        }
    }

    private func settingsButton(
        icon: String,
        title: String,
        detail: String,
        trailing: String? = nil,
        badge: Int = 0,
        destructive: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BondTheme.Space.md) {
                settingsLabel(
                    icon: icon,
                    title: title,
                    detail: detail,
                    destructive: destructive
                )
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(destructive ? Color.red : Color.primary)
        .disabled(disabled)
        .badge(badge)
    }

    private func settingsLabel(
        icon: String,
        title: String,
        detail: String,
        destructive: Bool = false
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
    }
}

struct ProfileVisitorsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if appState.profileVisits.isEmpty {
                    ContentUnavailableView(
                        L10n.Profile.noVisitors,
                        systemImage: "eye",
                        description: Text(L10n.Profile.noVisitorsBody)
                    )
                } else {
                    List(appState.profileVisits) { visit in
                        NavigationLink {
                            SocialPersonDetailView(profile: visit.profile, place: nil)
                        } label: {
                            HStack(spacing: BondTheme.Space.md) {
                                ProfileMedia(
                                    url: visit.profile.imageURL,
                                    data: nil,
                                    assetName: visit.profile.imageAssetName
                                )
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Text(visit.profile.name)
                                            .font(.system(size: 17, weight: .semibold))
                                        ProfileBadgeLabel(
                                            badge: visit.profile.badge,
                                            compact: true
                                        )
                                    }
                                    Text(DepartmentCatalog.display(visit.profile.department))
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Text(visit.visitedAt.relativeTurkish)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .refreshable { await appState.loadProfileVisits() }
            .task { await appState.loadProfileVisits() }
            .navigationTitle(L10n.Profile.visitors)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
    }
}

private struct ProfileSavedPostsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if appState.savedPosts.isEmpty {
                    ContentUnavailableView(
                        L10n.Profile.noSaved,
                        systemImage: "bookmark",
                        description: Text(L10n.Profile.noSavedBody)
                    )
                } else {
                    List(appState.savedPosts) { post in
                        HStack(spacing: BondTheme.Space.md) {
                            ProfileMedia(
                                url: post.imageURL,
                                data: post.localImageData,
                                assetName: post.imageAssetName
                            )
                            .frame(width: 56, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.author.name)
                                    .font(.system(size: 17, weight: .semibold))
                                Text(post.caption)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Button {
                                appState.toggleSaved(postID: post.id)
                            } label: {
                                Image(systemName: "bookmark.fill")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(L10n.Profile.unsave)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .task { await appState.loadSavedPosts() }
            .navigationTitle(L10n.Profile.saved)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
    }
}
