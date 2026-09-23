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
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if let loadError {
                    ScreenFailureView(message: loadError) {
                        Task { await reload() }
                    }
                    .listRowSeparator(.hidden)
                } else if people.isEmpty {
                    ContentUnavailableView(
                        L10n.Places.emptyHere,
                        systemImage: "person.2.slash",
                        description: Text(L10n.Places.emptyHereHint)
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(people) { profile in
                        HStack(spacing: BondTheme.Space.compact) {
                            Button {
                                selectedPerson = profile
                            } label: {
                                CampusPersonCard(profile: profile, showsDisclosure: false)
                            }
                            .buttonStyle(.plain)
                            if profile.id != appState.currentUserID {
                                meetupButton(for: profile)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { await reload() }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isHere ? L10n.Places.hideVisibility : L10n.Places.imHere) {
                        appState.togglePresence(at: place)
                    }
                    .disabled(appState.presenceUpdateID != nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let error = appState.presenceError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BondTheme.Space.md)
                        .padding(.vertical, BondTheme.Space.sm)
                }
            }
            .task { await appState.loadMeetingRequests() }
            .navigationDestination(item: $selectedPerson) { profile in
                SocialPersonDetailView(profile: profile, place: place)
            }
            .task(id: appState.currentVisiblePlace?.id) { await reload() }
        }
    }

    private func reload() async {
        do {
            people = try await appState.peopleAtPlace(place)
            loadError = nil
        } catch {
            guard !appState.isCancellation(error) else { return }
            loadError = UserFacingError.message(error, fallback: L10n.Places.peopleFailed)
        }
        isLoading = false
    }

    private var isHere: Bool { appState.currentVisiblePlace?.id == place.id }

    private func meetupButton(for profile: StudentProfile) -> some View {
        let sent = appState.meetingRequest(for: profile, at: place) != nil
        return MeetupCoffeeButton(sent: sent) {
            appState.sendMeetingRequest(to: profile, at: place)
        }
        .accessibilityLabel(sent ? L10n.Profile.requestSent : L10n.Places.sendMeetupA11y(profile.name))
        .accessibilityIdentifier("place.meetup.\(profile.id)")
    }
}
