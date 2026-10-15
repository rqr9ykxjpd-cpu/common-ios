import SwiftUI

struct ClubDetailView: View {
    let club: CampusClub
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing = false
    @State private var showPeople = false
    /// Açılan kart: kulüp hesabı ya da bir üye.
    @State private var cardProfile: StudentProfile?
    @State private var openingAccount = false
    @State private var members: [ClubMember] = []
    @State private var membersLoaded = false
    @State private var showAllMembers = false

    /// Sayfada gösterilen üye sayısı; fazlası "Tüm üyeler"de.
    private static let inlineMemberLimit = 5

    /// Düzenlendikten sonra güncel hali görünsün; kapatılırsa açıldığı hal kalır.
    private var current: CampusClub { appState.clubs.first { $0.id == club.id } ?? club }
    private var extras: ClubExtras? { appState.clubExtras[club.id] }
    private var canManage: Bool { appState.canManage(club.id) }
    private var joined: Bool { appState.isJoined(to: club) }
    private var accent: Color { Color(hex: current.accentHex) }
    /// Liste geldiyse onun sayısı: kartta "9 üye" yazıp listede 8 kişi
    /// görünmesin (kulüp hesabı ve engelliler listede yok). Sunucunun sayısında
    /// ben de varım; eskiden üstüne bir daha ekleniyordu.
    private var displayedMemberCount: Int { membersLoaded ? shownMembers.count : current.memberCount }
    /// Katılınca hemen listede olayım, ayrılınca hemen çıkayım; sunucuyu
    /// beklemeden. Kulüp hesabı kendi kulübünün listesinde yok.
    private var shownMembers: [ClubMember] {
        let ben = appState.currentUserID
        if members.contains(where: { $0.id == ben }) {
            return joined ? members : members.filter { $0.id != ben }
        }
        guard joined, !appState.isClubAccount else { return members }
        return members + [ClubMember(profile: appState.currentUserProfile, isManager: false)]
    }
    private var nextEvent: String { current.nextEvent.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Kulübün hesabı; kulüp hesabının kendisinde gösterilmez.
    private var accountLink: ClubAccountLink? {
        appState.clubAccountLink(forClub: club.id).flatMap { $0.profileID == appState.currentUserID ? nil : $0 }
    }

    var body: some View {
        ZStack {
            BondTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    header
                    identity
                    clubInfo
                    if let accountLink { accountEntry(accountLink) }
                    if !shownMembers.isEmpty { membersSection }
                    if canManage { peopleEntry }
                    // Etkinlik yoksa bölüm hiç görünmez.
                    if !nextEvent.isEmpty { upcomingEvent }
                    contact
                    benefits
                    membershipButton
                }
                .foregroundStyle(BondTheme.ink)
                .padding(BondTheme.Space.lg)
                .padding(.bottom, BondTheme.Space.lg)
            }
        }
        .transaction {
            if reduceMotion {
                $0.animation = nil
                $0.disablesAnimations = true
            }
        }
        .task {
            async let ek: Void = appState.loadClubExtras()
            async let baglar: Void = appState.loadClubAccountLinks()
            _ = await (ek, baglar)
        }
        // Katılınca/ayrılınca kulüpler yeniden yüklenip sayı değişiyor; liste
        // de tazelensin.
        .task(id: current.memberCount) { await loadMembers() }
        .sheet(item: $cardProfile) { profile in
            NavigationStack {
                SocialPersonDetailView(profile: profile, place: nil, showsClose: true)
            }
        }
        .sheet(isPresented: $editing) {
            ClubEditorView(clubID: club.id)
        }
        .sheet(isPresented: $showPeople) {
            ClubPeopleView(clubID: club.id, clubName: current.name)
        }
        .sheet(isPresented: $showAllMembers) {
            ClubMembersView(clubName: current.name, members: shownMembers)
        }
    }

    private var header: some View {
        HStack(spacing: BondTheme.Space.sm) {
            ClubLogoView(url: extras?.logoURL, icon: current.icon, accentHex: current.accentHex, size: 60)

            Spacer()

            if canManage {
                Button { editing = true } label: {
                    Text(L10n.ClubAdmin.edit)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(BondTheme.surface, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("club.edit")
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(BondTheme.surface, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L10n.Common.close)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Eyebrow(text: L10n.Club.yuClub, color: accent)
            Text(current.name)
                .editorialTitle(40)
                .fixedSize(horizontal: false, vertical: true)
            Text(current.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var clubInfo: some View {
        HStack(spacing: 10) {
            infoCard(
                value: "\(displayedMemberCount)",
                label: L10n.Club.members,
                icon: "person.2.fill",
                numeric: true
            )
            infoCard(
                value: joined ? L10n.Club.joinedStatus : L10n.Club.openStatus,
                label: L10n.Club.status,
                icon: joined ? "checkmark.circle.fill" : "door.left.hand.open"
            )
        }
    }

    private var upcomingEvent: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Club.upcoming, color: BondTheme.muted)

            HStack(spacing: 13) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                    Text(nextEvent)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let place = current.meetingPlace {
                        Label(place.name, systemImage: "mappin.and.ellipse")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                BondTheme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    /// Kulübün paylaşımları ve mesajları için profili.
    private func accountEntry(_ link: ClubAccountLink) -> some View {
        Button {
            Task { await openAccount(link) }
        } label: {
            HStack(spacing: 13) {
                ClubLogoView(url: extras?.logoURL, icon: current.icon, accentHex: current.accentHex, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.ClubSwitch.clubAccountRow)
                        .font(.headline)
                    if let username = link.username, !username.isEmpty {
                        Text("@" + username)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if openingAccount {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(openingAccount)
        .accessibilityIdentifier("club.account")
    }

    private func openAccount(_ link: ClubAccountLink) async {
        openingAccount = true
        defer { openingAccount = false }
        do {
            cardProfile = try await appState.clubAccountProfile(link.profileID)
        } catch {
            appState.showError(error, fallback: L10n.ClubSwitch.accountLoadFailed)
        }
    }

    /// Sessiz: sunucu eskiyse ya da ağ yoksa bölüm görünmez.
    private func loadMembers() async {
        do {
            members = try await appState.fetchClubMembers(club.id)
            membersLoaded = true
        } catch {}
    }

    /// Herkes için: kulüpte kim var. Dokununca kişinin kartı açılıyor.
    private var membersSection: some View {
        let liste = shownMembers
        return VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.ClubAdmin.members.lowercased(with: L10n.appLocale), color: BondTheme.muted)
            VStack(spacing: 0) {
                ForEach(liste.prefix(Self.inlineMemberLimit)) { uye in
                    if uye.id != liste.first?.id {
                        Divider().padding(.leading, 68)
                    }
                    ClubMemberRowView(member: uye) { cardProfile = uye.profile }
                }
                if liste.count > Self.inlineMemberLimit {
                    Divider()
                    Button { showAllMembers = true } label: {
                        HStack {
                            Text(L10n.ClubAdmin.allMembers(liste.count))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BondTheme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BondTheme.muted)
                        }
                        .padding(.horizontal, BondTheme.Space.md)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("club.members.all")
                }
            }
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Yönetici ve kurucu: üyeleri yönetme (çıkarma) listesi.
    private var peopleEntry: some View {
        Button { showPeople = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32)
                Text(L10n.ClubAdmin.manageMembers)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("club.people")
    }

    @ViewBuilder
    private var contact: some View {
        let instagram = extras?.instagram.flatMap { $0.isEmpty ? nil : $0 }
        let email = extras?.contactEmail.flatMap { $0.isEmpty ? nil : $0 }
        if instagram != nil || email != nil {
            VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
                Eyebrow(text: L10n.ClubAdmin.contact.lowercased(with: L10n.appLocale), color: BondTheme.muted)
                if let instagram, let url = URL(string: "https://instagram.com/\(instagram)") {
                    contactRow(icon: "camera", title: "@\(instagram)", action: L10n.ClubAdmin.openInstagram, url: url)
                }
                if let email, let url = URL(string: "mailto:\(email)") {
                    contactRow(icon: "envelope", title: email, action: L10n.ClubAdmin.sendEmail, url: url)
                }
            }
        }
    }

    private func contactRow(icon: String, title: String, action: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(action)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(BondTheme.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Club.whatToExpect, color: BondTheme.muted)
            benefit(L10n.Club.benefitMeet)
            benefit(L10n.Club.benefitEvents)
            benefit(L10n.Club.benefitProjects)
        }
    }

    private var membershipButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.bouncy) {
                appState.toggleClubMembership(club)
            }
        } label: {
            HStack(spacing: BondTheme.Space.sm) {
                Image(systemName: joined ? "checkmark.circle.fill" : "plus.circle.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(joined ? L10n.Club.leave : L10n.Club.join)
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(joined ? BondTheme.ink : Color.white)
            .padding(.horizontal, BondTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                joined ? BondTheme.surface : accent,
                in: Capsule()
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("club.membership")
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: joined)
    }

    private func infoCard(
        value: String,
        label: String,
        icon: String,
        numeric: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .contentTransition(.symbolEffect(.replace))
            Text(value)
                .font(.headline)
                .contentTransition(numeric ? .numericText() : .opacity)
                .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: value)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BondTheme.Space.md)
        .background(
            BondTheme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accent.opacity(0.12), in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
