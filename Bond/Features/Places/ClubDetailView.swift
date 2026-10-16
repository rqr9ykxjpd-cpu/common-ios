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
    @State private var selectedEvent: ClubRoute?
    @State private var composer: ClubEventComposerRoute?
    /// Etkinlikler bir kez denendi mi: sunucu eskiyse eski "yaklaşan etkinlik" metni.
    @State private var eventsChecked = false
    @State private var clubPosts: [SocialPost] = []
    @State private var openedPost: ClubRoute?

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
    private var events: [ClubEvent] { appState.clubEvents[club.id] ?? [] }
    /// Kulübün hesabı (herkes için): sayfadaki paylaşımlar onun gönderileri.
    private var accountProfileID: UUID? { appState.clubAccountLink(forClub: club.id)?.profileID }
    /// Gösterilecek paylaşımlar: silinenler düşer, en çok beş.
    private var visiblePosts: [SocialPost] {
        // Etkinlik gönderileri burada yok: etkinlikler zaten yukarıda.
        Array(clubPosts.filter { !appState.deletedPostIDs.contains($0.id) && appState.postEvents[$0.id] == nil }.prefix(5))
    }
    /// Kulübün hesabı: yalnızca kulübü yönetenler (kurucu ve kulübün
    /// yöneticileri) görür; üyeler kulübü sayfasından ve paylaşımlarından tanıyor.
    /// Kulüp hesabının kendisinde gösterilmez.
    private var accountLink: ClubAccountLink? {
        guard canManage else { return nil }
        return appState.clubAccountLink(forClub: club.id).flatMap { $0.profileID == appState.currentUserID ? nil : $0 }
    }

    var body: some View {
        ZStack {
            BondTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                    header
                    identity
                    if let accountLink { accountEntry(accountLink) }
                    if !events.isEmpty || canManage { eventsSection }
                    // Sunucuda etkinlikler yoksa (eski sunucu) eski düz metin.
                    if eventsChecked, appState.clubEvents[club.id] == nil, !nextEvent.isEmpty { upcomingEvent }
                    if !visiblePosts.isEmpty { postsSection }
                    if !shownMembers.isEmpty { membersSection }
                    if canManage { peopleEntry }
                    contact
                    // Kulübün hesabı kendi kulübünden ayrılamaz (sunucu da reddediyor).
                    if appState.clubAccountClubID != club.id { membershipButton }
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
            async let etkinlikler: Void = appState.loadClubEvents(club.id)
            _ = await (ek, baglar, etkinlikler)
            eventsChecked = true
        }
        .task(id: accountProfileID) {
            guard let accountProfileID else { return }
            let gelen = await appState.personPosts(for: accountProfileID)
            await appState.loadPostEvents(for: gelen)
            withAnimation(reduceMotion ? nil : BondTheme.Motion.smooth) { clubPosts = gelen }
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
        .sheet(item: $selectedEvent) { route in
            ClubEventDetailView(clubID: club.id, eventID: route.id, clubName: current.name,
                                accent: accent, canManage: canManage)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $composer) { route in
            ClubEventComposer(draft: route.draft, clubName: current.name, accent: accent)
        }
        .sheet(item: $openedPost) { route in
            NavigationStack { PostDetailView(postID: route.id, showsClose: true) }
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
            Eyebrow(text: L10n.Club.yuClub, color: BondTheme.muted)
            Text(current.name)
                .editorialTitle(40)
                .fixedSize(horizontal: false, vertical: true)
            Text(current.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            // Kaç kişi, nerede buluşuyor: tek satır. Üyelik durumu alttaki
            // düğmede; ayrı bir "Durum: Açık" kartı yok.
            Text([L10n.ClubAdmin.memberCount(displayedMemberCount), current.meetingPlace?.name]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(BondTheme.muted)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : BondTheme.Motion.snappy, value: displayedMemberCount)
        }
    }

    private var upcomingEvent: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.Club.upcoming, color: BondTheme.muted)

            HStack(spacing: 13) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(BondTheme.icon)
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
            cardProfile = try await appState.clubAccountProfile(forClub: link.clubID)
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

    /// Yaklaşan etkinlikler; yönetenler buradan yenisini açar.
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            HStack {
                Eyebrow(text: L10n.ClubEvents.sectionTitle, color: BondTheme.muted)
                Spacer()
                if canManage, !events.isEmpty {
                    Button {
                        composer = ClubEventComposerRoute(draft: ClubEventDraft(clubID: club.id, placeID: current.meetingPlace?.id))
                    } label: {
                        Label(L10n.ClubEvents.add, systemImage: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BondTheme.ink)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("club.event.add")
                }
            }
            ForEach(events) { etkinlik in
                ClubEventCard(event: etkinlik, accent: accent) {
                    selectedEvent = ClubRoute(id: etkinlik.id)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if events.isEmpty, canManage {
                Button {
                    composer = ClubEventComposerRoute(draft: ClubEventDraft(clubID: club.id, placeID: current.meetingPlace?.id))
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                            .foregroundStyle(BondTheme.icon)
                            .frame(width: 32)
                        Text(L10n.ClubEvents.add)
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
                .accessibilityIdentifier("club.event.add")
            }
        }
        .animation(reduceMotion ? nil : BondTheme.Motion.smooth, value: events.map(\.id))
    }

    /// Kulübün hesabının son paylaşımları; dokununca gönderi açılır.
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.compact) {
            Eyebrow(text: L10n.ClubEvents.postsTitle, color: BondTheme.muted)
            VStack(spacing: 0) {
                ForEach(visiblePosts) { gonderi in
                    if gonderi.id != visiblePosts.first?.id {
                        Divider().padding(.leading, BondTheme.Space.md)
                    }
                    Button {
                        Task {
                            if await appState.loadPostIfNeeded(gonderi.id) {
                                openedPost = ClubRoute(id: gonderi.id)
                            }
                        }
                    } label: {
                        ProfilePostRow(post: gonderi)
                            .padding(.horizontal, BondTheme.Space.md)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
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
                    .foregroundStyle(BondTheme.icon)
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
                    .foregroundStyle(BondTheme.icon)
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

    private var membershipButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : BondTheme.Motion.bouncy) {
                appState.toggleClubMembership(club)
            }
        } label: {
            Text(joined ? L10n.Club.leave : L10n.Club.join)
                .font(.headline)
                .foregroundStyle(joined ? BondTheme.ink : BondTheme.paper)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(joined ? BondTheme.surface : BondTheme.ink, in: Capsule())
                .contentTransition(.opacity)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("club.membership")
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: joined)
    }
}

/// Sayfadan açılan sayfa için kimlik (etkinlik ya da gönderi).
struct ClubRoute: Identifiable, Hashable {
    let id: UUID
}

struct ClubEventComposerRoute: Identifiable {
    let id = UUID()
    let draft: ClubEventDraft
}
