import SwiftUI

struct MeetingRequestsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let initialRequestID: UUID?
    @State private var selectedSegment = 0
    @State private var conversationRoute: MeetingConversationRoute?

    init(initialRequestID: UUID? = nil) {
        self.initialRequestID = initialRequestID
    }

    private var requests: [MeetingRequest] {
        let direction: MeetingRequestDirection = selectedSegment == 0 ? .incoming : .outgoing
        return appState.meetingRequests
            .filter { $0.direction == direction }
            .sorted { lhs, rhs in
                if lhs.id == initialRequestID { return true }
                if rhs.id == initialRequestID { return false }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.Meetings.direction, selection: $selectedSegment) {
                    Text(L10n.Meetings.incoming).tag(0)
                    Text(L10n.Meetings.outgoing).tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.vertical, BondTheme.Space.md)

                if requests.isEmpty {
                    ContentUnavailableView(
                        selectedSegment == 0 ? L10n.Meetings.noIncoming : L10n.Meetings.noOutgoing,
                        systemImage: "cup.and.saucer",
                        description: Text(selectedSegment == 0 ? L10n.Meetings.noIncomingBody : L10n.Meetings.noOutgoingBody)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: BondTheme.Space.md) {
                            ForEach(requests) { request in
                                requestCard(request)
                            }
                        }
                        .padding(BondTheme.Space.lg)
                        .padding(.bottom, BondTheme.Space.xl)
                    }
                }
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Meetings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await appState.loadMeetingRequests() }
            .refreshable { await appState.loadMeetingRequests() }
            .onAppear {
                if let initialRequestID,
                   let request = appState.meetingRequests.first(where: { $0.id == initialRequestID }) {
                    selectedSegment = request.direction == .incoming ? 0 : 1
                }
            }
            .fullScreenCover(item: $conversationRoute) { route in
                NavigationStack { ConversationView(conversationID: route.id, showsClose: true) }
            }
        }
    }

    private func requestCard(_ request: MeetingRequest) -> some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            HStack(alignment: .top, spacing: BondTheme.Space.md) {
                NavigationLink {
                    SocialPersonDetailView(profile: request.profile, place: request.place)
                } label: {
                    HStack(alignment: .top, spacing: BondTheme.Space.md) {
                        ProfileMedia(url: request.profile.imageURL, data: nil, assetName: request.profile.imageAssetName)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(request.profile.name)
                                .font(.system(size: 17, weight: .bold))
                            Label(request.place.name, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BondTheme.violet)
                            Text(request.createdAt.relativeTurkish)
                                .font(.system(size: 11))
                                .foregroundStyle(BondTheme.muted)
                        }
                    }
                    .foregroundStyle(BondTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Feed.openProfile(request.profile.name))
                Spacer()
                Text(request.status.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor(request.status))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(statusColor(request.status).opacity(0.1), in: Capsule())
            }

            if request.direction == .incoming && request.status == .pending {
                HStack(spacing: BondTheme.Space.sm) {
                    AppButton(title: L10n.Chat.decline, systemName: "xmark", role: .secondary) {
                        appState.respondToMeetingRequest(request.id, accept: false)
                    }
                    AppButton(title: L10n.Chat.accept, systemName: "checkmark", role: .accent) {
                        appState.respondToMeetingRequest(request.id, accept: true)
                    }
                }
            } else if request.status == .accepted {
                AppButton(title: L10n.Profile.sendMessage, systemName: "message.fill", role: .primary) {
                    // Buluşmanın kabul edilmesi eşleşme anlamına gelmiyor;
                    // mesajlaşma eşleşmeye bağlı.
                    if let id = appState.conversationID(for: request.profile) {
                        conversationRoute = MeetingConversationRoute(id: id)
                    } else {
                        appState.show(L10n.Profile.needMatchToChat)
                    }
                }
            } else if request.direction == .outgoing && request.status == .pending {
                Text(L10n.Meetings.waitingNote)
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(BondTheme.Space.lg)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BondTheme.Radius.card, style: .continuous)
                .stroke(request.id == initialRequestID ? BondTheme.violet : BondTheme.hairline, lineWidth: request.id == initialRequestID ? 1.5 : 1)
        }
    }

    private func statusColor(_ status: MeetingRequestStatus) -> Color {
        switch status {
        case .pending: BondTheme.coral
        case .accepted: Color.green
        case .declined: BondTheme.muted
        }
    }
}

private struct MeetingConversationRoute: Identifiable {
    let id: UUID
}
