import SwiftUI

struct ProfileDetailSheet: View {
    let profile: StudentProfile
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto = 0
    @State private var details: PersonProfileData?
    @State private var showBlockConfirmation = false

    /// Gönderiler isme göre süzülüyordu: aynı adlı iki kişi karışırdı ve akışa
    /// girmemiş gönderiler hiç görünmezdi. Artık kişinin gönderileri sunucudan,
    /// kimliğine göre geliyor — kişi profilinin diğer girişleriyle aynı yol.
    private var profilePosts: [SocialPost] { details?.posts ?? [] }

    private var galeri: [URL] {
        let uzak = details?.galleryURLs ?? []
        if !uzak.isEmpty { return uzak }
        if !profile.galleryImageURLs.isEmpty { return profile.galleryImageURLs }
        return [profile.imageURL].compactMap { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BondTheme.Space.xl) {
                gallery
                identity
                compatibility
                interests
                posts
                safetyActions
            }
            .padding(.bottom, BondTheme.Space.xl)
        }
        .task { details = await appState.personDetails(for: profile.id) }
        .background(BondTheme.paper.ignoresSafeArea())
        .foregroundStyle(BondTheme.ink)
        .safeAreaInset(edge: .bottom, spacing: 0) { decisionBar }
        .confirmationDialog(
            L10n.Chat.blockConfirm(profile.name),
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Feed.blockUser, role: .destructive) {
                appState.block(profile)
                dismiss()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Chat.blockBody)
        }
    }

    private var galleryPageCount: Int { max(galeri.count, 1) }

    private var gallery: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedPhoto) {
                if galeri.isEmpty {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: nil)
                        .frame(maxWidth: .infinity)
                        .frame(height: 460)
                        .clipped()
                        .tag(0)
                } else {
                    ForEach(Array(galeri.enumerated()), id: \.offset) { index, url in
                        ProfileMedia(url: url, data: nil, assetName: nil)
                            .frame(maxWidth: .infinity)
                            .frame(height: 460)
                            .clipped()
                            .tag(index)
                    }
                }
            }
            .frame(height: 460)
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 5) {
                ForEach(0..<galleryPageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPhoto ? .white : .white.opacity(0.42))
                        .frame(width: index == selectedPhoto ? 20 : 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.black.opacity(0.28), in: Capsule())
            .padding(.top, 14)
            .padding(.trailing, 66)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .accessibilityLabel(L10n.Common.close)
            .buttonStyle(PressableStyle())
            .padding(14)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(profile.name)
                    .font(.system(size: 32, weight: .bold))
                Text("\(profile.age)")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(BondTheme.muted)
                ProfileBadgeLabel(badge: profile.badge, compact: true)
                Spacer()
                Text(L10n.Discovery.compatibility(profile.compatibility))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BondTheme.violet)
            }
            Label("\(DepartmentCatalog.display(profile.department)) · \(AcademicYear.display(profile.year))", systemImage: "graduationcap.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BondTheme.muted)
            Text(profile.bio)
                .font(.system(size: 16))
                .lineSpacing(4)
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }

    private var compatibility: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                AppSectionHeader(title: L10n.Discovery.whyCompatible)
                ForEach(profile.compatibilityReasons, id: \.self) { reason in
                    Label(CompatibilityCopy.localize(reason), systemImage: "sparkles")
                }
                if !profile.activeLabel.isEmpty {
                    Label(profile.activeLabel, systemImage: "clock")
                }
            }
            .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }


    private var interests: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            AppSectionHeader(title: L10n.Discovery.interests)
            HStack(spacing: BondTheme.Space.sm) {
                ForEach(profile.interests, id: \.self) { interest in
                    Text(InterestCatalog.displayName(interest))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(BondTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(BondTheme.hairline))
                }
            }
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }

    private func visiblePlace(_ place: CampusPlace) -> some View {
        HStack(spacing: BondTheme.Space.md) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(BondTheme.violet)
                .frame(width: 40, height: 40)
                .background(BondTheme.violet.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Discovery.visibleNow)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(BondTheme.muted)
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
            }
            Spacer()
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }

    @ViewBuilder
    private var posts: some View {
        if !profilePosts.isEmpty {
            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                AppSectionHeader(title: L10n.Discovery.theirPosts)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BondTheme.Space.sm) {
                        ForEach(profilePosts) { post in
                            ProfileMedia(url: post.imageURL, data: post.localImageData, assetName: post.imageAssetName)
                                .frame(width: 150, height: 188)
                                .clipShape(RoundedRectangle(cornerRadius: BondTheme.Radius.media, style: .continuous))
                        }
                    }
                }
            }
            .padding(.horizontal, BondTheme.Space.lg)
        }
    }

    private var safetyActions: some View {
        Menu {
            Menu {
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) { appState.report(profile, reason: reason) }
                }
            } label: {
                Label(L10n.Common.report, systemImage: "flag")
            }
            Button(L10n.Feed.blockUser, role: .destructive) {
                showBlockConfirmation = true
            }
        } label: {
            Label(L10n.Discovery.safety, systemImage: "shield")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BondTheme.muted)
        }
        .padding(.horizontal, BondTheme.Space.lg)
    }

    private var decisionBar: some View {
        HStack(spacing: BondTheme.Space.md) {
            AppButton(title: L10n.Discovery.pass, systemName: "xmark", role: .secondary) { react(liked: false) }
            AppButton(title: L10n.Discovery.meet, systemName: "heart.fill", role: .accent) { react(liked: true) }
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.vertical, BondTheme.Space.md)
        .background(BondTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private func react(liked: Bool) {
        dismiss()
        Task { await appState.react(to: profile, liked: liked) }
    }
}

