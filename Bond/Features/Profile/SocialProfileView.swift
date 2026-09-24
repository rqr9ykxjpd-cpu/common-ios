import SwiftUI

/// The owner's home, not the public profile card: identity, usable membership
/// features and posts. Gallery management stays in the existing editor.
struct SocialProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showPhoto = false
    /// Sayfa yukarıdan ne kadar aşağı çekildi. Yalnızca fotoğraf okuyor; sayfanın
    /// geri kalanı her karede yeniden çizilmesin diye ayrı bir nesnede.
    @State private var pull = PullAmount()
    @State private var showComposer = false
    @State private var showEditor = false
    @State private var showMyCard = false
    @State private var showSettings = false
    @State private var showSaved = false
    @State private var showVisits = false
    @State private var showRequests = false
    @State private var showPaywall = false
    @State private var selectedPost: SocialPost?
    @State private var profilePosts: [SocialPost] = []
    @State private var loadingPosts = true
    @State private var loadID = UUID()

    private var displayName: String { appState.draft.name.isEmpty ? L10n.Common.you : appState.draft.name }
    private var hasAvatar: Bool { appState.avatarURL != nil || appState.avatarData != nil }
    private var pendingRequestCount: Int {
        appState.introductionRequests.count
            + appState.pendingMessageRequests.count
            + appState.pendingIncomingMeetingRequestCount
    }
    private var featuredInterests: [String] {
        Array(appState.draft.interests).sorted().prefix(3).map { $0 }
    }

    private var galleryPhotos: [ProfileGalleryPhoto] {
        if !appState.galleryURLs.isEmpty {
            return ProfileGalleryPhoto.remote(appState.galleryURLs)
        }
        return appState.profileGalleryData.enumerated().map { index, data in
            ProfileGalleryPhoto(id: "local-gallery-\(index)", url: nil, data: data, assetName: nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    identity
                    if appState.eduNeedsAttention { EduVerificationCard() }
                    tools
                    gallery
                    posts
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, -(geo.contentOffset.y + geo.contentInsets.top))
            } action: { _, yeni in
                pull.amount = yeni
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .foregroundStyle(BondTheme.ink)
            .tint(BondTheme.ink)
            .navigationTitle(L10n.Tabs.profile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(L10n.Profile.moreSettings)
                        .accessibilityIdentifier("profile.settings")
                }
            }
            .task(id: appState.currentUserID) { await reload() }
            .refreshable { await reload() }
            .fullScreenCover(isPresented: $showEditor) {
                NavigationStack { ProfileEditorView() }
            }
            .fullScreenCover(isPresented: $showMyCard) {
                NavigationStack {
                    ProfilePhotoStackView(profile: appState.currentUserProfile, showsClose: true)
                }
            }
            .sheet(isPresented: $showSettings) { ProfileSettingsView() }
            .sheet(isPresented: $showSaved) { ProfileSavedPostsView() }
            .sheet(isPresented: $showVisits) { ProfileVisitorsView() }
            .sheet(isPresented: $showRequests) { ProfileRequestsHubView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .fullScreenCover(isPresented: $showPhoto) {
                PhotoZoomView(url: appState.avatarURL, data: appState.avatarData)
            }
            .sheet(isPresented: $showComposer) { CreatePostView() }
            .onChange(of: showComposer) { _, open in
                if !open { Task { await reload() } }
            }
            .sheet(item: $selectedPost) { post in
                NavigationStack {
                    ScrollView {
                        let current = displayedPosts.first { $0.id == post.id } ?? post
                        PostCard(post: current,
                                 toggleLike: { appState.toggleLike(postID: post.id) },
                                 toggleSaved: { appState.toggleSaved(postID: post.id) },
                                 openProfile: {},
                                 delete: {
                                     appState.deletePost(post.id)
                                     profilePosts.removeAll { $0.id == post.id }
                                     selectedPost = nil
                                 })
                            .padding(.vertical, 16)
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.Common.close) { selectedPost = nil }
                        }
                    }
                }
            }
#if DEBUG
            .onAppear { if appState.opensModeration { showSettings = true } }
#endif
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 16) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    avatar
                    nameAndEducation
                    editProfileButton
                }
            } else {
                HStack(alignment: .center, spacing: 20) {
                    avatar
                    nameAndEducation
                    editProfileButton
                }
            }
            if !appState.draft.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(appState.draft.bio)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.about")
            } else {
                Button { showEditor = true } label: {
                    Label(L10n.Profile.writeAbout, systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BondTheme.muted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            if !featuredInterests.isEmpty {
                FlowLayout(spacing: BondTheme.Space.sm) {
                    ForEach(featuredInterests, id: \.self) { interest in
                        Text(interest)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(BondTheme.surface, in: Capsule())
                    }
                }
                .accessibilityIdentifier("profile.interests")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: BondTheme.Space.sm) { shareButton; previewButton }
                VStack(spacing: BondTheme.Space.sm) { shareButton; previewButton }
            }
        }
    }

    private var avatar: some View {
        PullStretch(pull: pull) {
            avatarTile
        }
        .accessibilityIdentifier("profile.avatar")
    }

    private var avatarTile: some View {
        ZStack(alignment: .bottomTrailing) {
            Button {
                if hasAvatar { showPhoto = true } else { showEditor = true }
            } label: {
                ProfileMedia(url: appState.avatarURL, data: appState.avatarData)
                    .frame(width: 96, height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasAvatar ? L10n.Profile.zoomPhoto : L10n.ScreenStates.addPhoto)

            Button { showEditor = true } label: {
                Image(systemName: "camera.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BondTheme.onAccent)
                    .frame(width: 34, height: 34)
                    .background(BondTheme.acid, in: Circle())
                    .overlay(Circle().stroke(BondTheme.paper, lineWidth: 3))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Profile.editA11y)
        }
    }

    private var nameAndEducation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName).font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text([appState.draft.department, AcademicYear.display(appState.draft.year)]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // İki rozet dar sütuna sığmayınca alt satıra insin; HStack sütunu taşırıyordu.
            FlowLayout(spacing: 6) {
                ProfileBadgeLabel(badge: appState.myBadge, compact: true)
                if appState.eduStatus?.isVerified == true { EduStudentChip() }
            }
            // Kurucu künyesi kendi profilinde de görünsün; kartta zaten vardı.
            if appState.myBadge == .founder {
                FounderCredLine(size: 15)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editProfileButton: some View {
        Button { showEditor = true } label: {
            Image(systemName: "pencil")
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(BondTheme.surface, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(L10n.Profile.editA11y)
        .accessibilityIdentifier("profile.edit")
    }

    private var previewButton: some View {
        compactAction(title: L10n.ProfileHome.publicPreview, icon: "eye", primary: false) { showMyCard = true }
            .accessibilityIdentifier("profile.viewCard")
    }

    private var shareButton: some View {
        compactAction(title: L10n.ProfileHome.share, icon: "plus", primary: true) { showComposer = true }
            .accessibilityIdentifier("profile.compose")
    }

    private func compactAction(
        title: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(primary ? BondTheme.onAccent : BondTheme.ink)
                .background(primary ? BondTheme.acid : BondTheme.surface, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            AppSectionHeader(
                title: L10n.ProfileHome.photos,
                actionTitle: L10n.ProfileHome.manage
            ) { showEditor = true }

            if galleryPhotos.isEmpty {
                Button { showEditor = true } label: {
                    HStack(spacing: BondTheme.Space.md) {
                        Image(systemName: "photo.stack")
                            .font(.title2)
                            .frame(width: 48, height: 48)
                            .background(BondTheme.paper, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.ProfileHome.addPhotos)
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.ProfileDesign.galleryOwnEmpty)
                                .font(.footnote)
                                .foregroundStyle(BondTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BondTheme.muted)
                    }
                    .foregroundStyle(BondTheme.ink)
                    .padding(BondTheme.Space.md)
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                    .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("profile.gallery.empty")
            } else {
                ProfileGalleryStack(photos: galleryPhotos, height: 264)
            }
        }
    }

    private var tools: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            AppSectionHeader(title: L10n.ProfileHome.tools)

            requestSummaryCard

            if typeSize.isAccessibilitySize {
                VStack(spacing: BondTheme.Space.sm) {
                    membershipTool(
                        icon: "eye",
                        title: L10n.Profile.visitors,
                        value: appState.tier.canSeeProfileVisitors ? L10n.ProfileHome.on : L10n.Tier.plus
                    ) {
                        if appState.tier.canSeeProfileVisitors { showVisits = true }
                        else { showPaywall = true }
                    }
                    .accessibilityIdentifier("profile.visitors")

                    membershipTool(
                        icon: "eye.slash",
                        title: L10n.Profile.ghost,
                        value: appState.tier.hasGhostMode
                            ? (appState.ghostMode ? L10n.ProfileHome.on : L10n.Common.off)
                            : L10n.Tier.pro
                    ) { toggleGhostMode() }
                    .accessibilityIdentifier("profile.ghost")

                    planTile
                }
            } else {
                HStack(spacing: BondTheme.Space.sm) {
                    membershipTool(
                        icon: "eye",
                        title: L10n.Profile.visitors,
                        value: appState.tier.canSeeProfileVisitors ? L10n.ProfileHome.on : L10n.Tier.plus
                    ) {
                        if appState.tier.canSeeProfileVisitors { showVisits = true }
                        else { showPaywall = true }
                    }
                    .accessibilityIdentifier("profile.visitors")

                    membershipTool(
                        icon: "eye.slash",
                        title: L10n.Profile.ghost,
                        value: appState.tier.hasGhostMode
                            ? (appState.ghostMode ? L10n.ProfileHome.on : L10n.Common.off)
                            : L10n.Tier.pro
                    ) { toggleGhostMode() }
                    .accessibilityIdentifier("profile.ghost")

                    planTile
                }
            }

            Text(L10n.ProfileHome.planPrivate)
                .font(.custom("BradleyHandITCTT-Bold", size: 15, relativeTo: .footnote))
                .foregroundStyle(BondTheme.burntOrange)
                .rotationEffect(.degrees(-0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var requestSummaryCard: some View {
        Button { showRequests = true } label: {
            HStack(spacing: BondTheme.Space.compact) {
                Image(systemName: pendingRequestCount > 0 ? "tray.full.fill" : "tray")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(pendingRequestCount > 0 ? BondTheme.onAccent : BondTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(
                        pendingRequestCount > 0 ? BondTheme.burntOrange : BondTheme.paper,
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        pendingRequestCount > 0
                            ? L10n.ProfileHome.pendingRequests(pendingRequestCount)
                            : L10n.ProfileHome.noPendingRequests
                    )
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())

                    // Boşken de ne olduğu okunsun: buluşma istekleri burada.
                    Text(L10n.ProfileHome.requestsDetail)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: BondTheme.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BondTheme.muted)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(BondTheme.ink)
            .padding(.horizontal, BondTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: pendingRequestCount > 0 ? 76 : 64, alignment: .leading)
            .background(
                pendingRequestCount > 0 ? BondTheme.burntOrange.opacity(0.10) : BondTheme.surface,
                in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .animation(BondTheme.Motion.smooth, value: pendingRequestCount)
        .accessibilityIdentifier("profile.requests")
    }

    /// Plan kutucuğu altın: ücretsizde "PLUS'A GEÇ" ve düzenli parlama,
    /// Plus/Pro'da plan adı ve açılışta tek parlama.
    private var planTile: some View {
        PlusGoldTile(
            title: L10n.ProfileHome.myPlan,
            value: appState.tier == .free ? L10n.Paywall.goPlus : appState.tier.title,
            invites: appState.tier == .free,
            minHeight: typeSize.isAccessibilitySize ? 98 : 108
        ) { showPaywall = true }
        .accessibilityIdentifier("profile.plus")
    }

    private func membershipTool(
        icon: String,
        title: String,
        value: String,
        accent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent ? BondTheme.burntOrange : BondTheme.ink)
                    .frame(width: 34, height: 34)
                    .background(BondTheme.paper, in: Circle())

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent ? BondTheme.burntOrange : BondTheme.muted)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(BondTheme.ink)
            .padding(BondTheme.Space.compact)
            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 98 : 108, alignment: .leading)
            .background(
                accent ? BondTheme.burntOrange.opacity(0.08) : BondTheme.surface,
                in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func toggleGhostMode() {
        if appState.tier.hasGhostMode {
            withAnimation(BondTheme.Motion.snappy) {
                appState.setGhostMode(!appState.ghostMode)
            }
            Haptics.selection()
        } else {
            showPaywall = true
        }
    }

    private var posts: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.Profile.myPosts).font(.title3.weight(.semibold))
                Spacer()
                Button { showSaved = true } label: {
                    Label(L10n.Profile.saved, systemImage: "bookmark")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(BondTheme.surface, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Profile.saved)
                .accessibilityIdentifier("profile.saved")
            }
            if loadingPosts && displayedPosts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in Skeleton(height: 76, cornerRadius: 12) }
                }
            } else if displayedPosts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.Profile.firstPostBody).font(.subheadline).foregroundStyle(.secondary)
                    Button(L10n.Profile.shareCta) { showComposer = true }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
            } else {
                LazyVStack(spacing: 20) {
                    ForEach(displayedPosts) { post in
                        Button { selectedPost = post } label: {
                            ProfilePostRow(post: post).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }

    private func reload() async {
        let operation = UUID()
        let account = appState.currentUserID
        loadID = operation
        loadingPosts = true
        defer { if loadID == operation { loadingPosts = false } }

        async let fetchedPosts = appState.personPosts(for: account)
        async let edu: Void = appState.loadEduStatus()
        async let introductions: Void = appState.loadIntroductionRequests()
        async let meetings: Void = appState.loadMeetingRequests(silently: true)
        async let messages: Void = appState.loadMessageRequests(silently: true)
        let fetched = await fetchedPosts
        _ = await (introductions, meetings, messages, edu)

        guard loadID == operation, account == appState.currentUserID, !Task.isCancelled else { return }
        profilePosts = fetched
        if appState.tier.canSeeProfileVisitors { await appState.loadProfileVisits(silently: true) }
    }

    private var displayedPosts: [SocialPost] {
        var byID: [UUID: SocialPost] = [:]
        for post in profilePosts { byID[post.id] = post }
        for post in appState.currentUserPosts { byID[post.id] = post }
        return byID.values.sorted { $0.createdAt > $1.createdAt }
    }
}

/// Requests were split between Chat and Settings, so users had to know the
/// implementation detail to find them. This is a lightweight directory: the
/// existing request screens still own the actions and server communication.
private struct ProfileRequestsHubView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showConnectionRequests = false
    @State private var showMeetingRequests = false

    private var connectionRequestCount: Int {
        appState.introductionRequests.count + appState.pendingMessageRequests.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                    Text(L10n.ProfileHome.requestsIntro)
                        .font(.subheadline)
                        .foregroundStyle(BondTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    requestRow(
                        icon: "person.crop.circle.badge.plus",
                        title: L10n.ProfileHome.connectionRequests,
                        detail: L10n.ProfileHome.connectionRequestsDetail,
                        count: connectionRequestCount
                    ) { showConnectionRequests = true }

                    requestRow(
                        icon: "cup.and.saucer",
                        title: L10n.ProfileHome.meetingRequests,
                        detail: L10n.ProfileHome.meetingRequestsDetail,
                        count: appState.pendingIncomingMeetingRequestCount
                    ) { showMeetingRequests = true }
                }
                .padding(BondTheme.Space.lg)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.ProfileHome.requests)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task {
                async let introductions: Void = appState.loadIntroductionRequests()
                async let meetings: Void = appState.loadMeetingRequests(silently: true)
                async let messages: Void = appState.loadMessageRequests(silently: true)
                _ = await (introductions, meetings, messages)
            }
            .sheet(isPresented: $showConnectionRequests) {
                PremiumMatchesView()
            }
            .sheet(isPresented: $showMeetingRequests) {
                MeetingRequestsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func requestRow(
        icon: String,
        title: String,
        detail: String,
        count: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: BondTheme.Space.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .background(BondTheme.paper, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.bold())
                        .foregroundStyle(BondTheme.onAccent)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(BondTheme.acid, in: Capsule())
                        .accessibilityLabel(L10n.ScreenStates.unread(count))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BondTheme.muted)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(BondTheme.ink)
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Sayfa yukarıdan aşağı çekildiğinde fotoğraf hafifçe büyür, bırakınca yerine
/// döner (en fazla %15). Çekme miktarı gözlenen bir nesnede; yalnızca bu
/// görünüm yeniden çiziliyor.
@Observable
private final class PullAmount {
    var amount: CGFloat = 0
}

private struct PullStretch<Content: View>: View {
    let pull: PullAmount
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let olcek = reduceMotion ? 1 : 1 + min(pull.amount, 150) / 1000
        content.scaleEffect(olcek, anchor: .bottom)
    }
}
