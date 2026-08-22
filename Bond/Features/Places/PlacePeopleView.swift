import SwiftUI

struct PlacePeopleView: View {
    let place: CampusPlace
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var people: [StudentProfile] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var selectedPerson: StudentProfile?

    var body: some View {
        NavigationStack {
            ZStack {
                BondTheme.paper.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        placeHeader
                        if isLoading {
                            ProgressView()
                                .tint(BondTheme.violet)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if let loadError {
                            ContentUnavailableView {
                                Label(L10n.Errors.title, systemImage: "wifi.exclamationmark")
                            } description: {
                                Text(loadError)
                            } actions: {
                                Button(L10n.Common.retry) {
                                    Task { await reload() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BondTheme.acid)
                            }
                        } else if people.isEmpty {
                            // Kimse görünmüyorsa bunu açıkça söylüyoruz; eskiden sahte
                            // isimlerle dolu olduğu için boş durum hiç görünmüyordu.
                            VStack(spacing: 8) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 26, weight: .light))
                                Text(L10n.Places.emptyHere)
                                    .font(.system(size: 15, weight: .bold))
                                Text(L10n.Places.emptyHereHint)
                                    .font(.system(size: 12))
                                    .foregroundStyle(BondTheme.ink.opacity(0.5))
                            }
                            .foregroundStyle(BondTheme.ink.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(people) { profile in
                                personRow(profile)
                            }
                        }
                    }
                    .padding(18)
                }
                .refreshable { await reload() }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .navigationDestination(item: $selectedPerson) { profile in
                SocialPersonDetailView(profile: profile, place: place)
            }
            // Görünürlüğü açıp kapatmak listeyi tazelemiyordu: "buradayım" dedikten
            // sonra liste hâlâ eski halini gösteriyor, kullanıcı kendini göremiyordu.
            .task(id: appState.currentVisiblePlace?.id) { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            people = try await appState.peopleAtPlace(place)
            loadError = nil
        } catch {
            guard !appState.isCancellation(error) else { return }
            loadError = UserFacingError.message(error, fallback: L10n.Places.peopleFailed)
        }
    }

    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Places.visibleStudents)
                .font(.system(size: 15))
                .foregroundStyle(BondTheme.ink.opacity(0.5))
            // Kendisi artık listenin içinde; elle eklemek iki kez sayardı.
            Label(L10n.Places.visibleCount(people.count), systemImage: "person.2.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BondTheme.violet)

            Button { appState.togglePresence(at: place) } label: {
                HStack {
                    Image(systemName: isHere ? "checkmark.circle.fill" : "location.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isHere ? L10n.Places.youAreHere : L10n.Places.imHere)
                            .font(.system(size: 11, weight: .black)).tracking(1)
                        Text(isHere ? L10n.Places.tapToHide : L10n.Places.makeVisible)
                            .font(.system(size: 12)).opacity(0.65)
                    }
                    Spacer()
                }
                .foregroundStyle(isHere ? .white : BondTheme.onAccent)
                .padding(.horizontal, 15).frame(height: 58)
                .background(isHere ? BondTheme.violet : BondTheme.acid, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private var isHere: Bool { appState.currentVisiblePlace?.id == place.id }

    /// Satır iki ayrı dokunma alanına bölündü: soldaki profili açıyor, sağdaki
    /// doğrudan buluşma isteği gönderiyor. Eskiden bütün satır tek bir bağlantıydı
    /// ve buluşma isteği ancak profile girip aşağı inince görünüyordu — aynı
    /// kafedeki birine seslenmek için üç dokunuş gerekiyordu.
    private func personRow(_ profile: StudentProfile) -> some View {
        let benMiyim = profile.id == appState.currentUserID
        let bekleyen = appState.meetingRequest(for: profile, at: place)
        return HStack(spacing: 10) {
            Button {
                selectedPerson = profile
            } label: {
                HStack(spacing: 13) {
                    ProfileMedia(url: profile.imageURL, data: nil, assetName: profile.imageAssetName)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Text("\(profile.name), \(profile.age)").font(.system(size: 17, weight: .semibold))
                            ProfileBadgeLabel(badge: profile.badge, compact: true)
                        }
                        Text("\(profile.department) · \(AcademicYear.display(profile.year))")
                            .font(.system(size: 12)).foregroundStyle(BondTheme.ink.opacity(0.5))
                        Label(place.name, systemImage: "location.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(BondTheme.violet)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())

            if benMiyim {
                Text(L10n.Common.youBadge)
                    .font(.system(size: 10, weight: .black)).tracking(0.6)
                    .foregroundStyle(BondTheme.muted)
            } else {
                Button {
                    Haptics.impact(.light)
                    appState.sendMeetingRequest(to: profile, at: place)
                } label: {
                    Image(systemName: bekleyen == nil ? "cup.and.saucer.fill" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bekleyen == nil ? BondTheme.onAccent : BondTheme.ink.opacity(0.55))
                        .frame(width: 46, height: 46)
                        .background(bekleyen == nil ? BondTheme.acid : BondTheme.ink.opacity(0.08), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(bekleyen != nil)
                .accessibilityLabel(bekleyen == nil ? L10n.Places.sendMeetupA11y(profile.name) : L10n.Profile.requestSent)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(13)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
