import SwiftUI

struct MeetingRequestsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let initialRequestID: UUID?
    @State private var selectedSegment = 0
    @State private var conversationRoute: MeetingConversationRoute?
    @State private var respondingRequestID: UUID?

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
            .task {
                await appState.loadMeetingRequests()
                await appState.loadConversations()
            }
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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: BondTheme.Space.md) {
                    requestProfileLink(request)
                    Spacer(minLength: BondTheme.Space.sm)
                    statusLabel(request.status)
                }
                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    requestProfileLink(request)
                    statusLabel(request.status)
                }
            }

            if request.direction == .incoming && request.status == .pending {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: BondTheme.Space.sm) {
                        declineButton(for: request)
                        acceptButton(for: request)
                    }
                    VStack(spacing: BondTheme.Space.sm) {
                        declineButton(for: request)
                        acceptButton(for: request)
                    }
                }
            } else if request.status == .accepted {
                AppButton(title: L10n.Profile.sendMessage, systemName: "message.fill", role: .primary) {
                    if let id = appState.conversationID(for: request.profile) {
                        conversationRoute = MeetingConversationRoute(id: id)
                    } else {
                        appState.show(L10n.Profile.needMatchToChat)
                    }
                }
            } else if request.direction == .outgoing && request.status == .pending {
                Text(L10n.Meetings.waitingNote)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .padding(BondTheme.Space.lg)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
                .stroke(request.id == initialRequestID ? BondTheme.violet : BondTheme.hairline, lineWidth: request.id == initialRequestID ? 1.5 : 1)
        }
    }

    private func requestProfileLink(_ request: MeetingRequest) -> some View {
        NavigationLink {
            SocialPersonDetailView(profile: request.profile, place: request.place)
        } label: {
            HStack(alignment: .top, spacing: BondTheme.Space.md) {
                ProfileMedia(url: request.profile.imageURL, data: nil, assetName: request.profile.imageAssetName)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: BondTheme.Space.xs) {
                    Text(request.profile.name)
                        .font(BondTheme.Typography.headline)
                    Label(request.place.name, systemImage: "mappin.and.ellipse")
                        .font(BondTheme.Typography.footnote.weight(.semibold))
                        .foregroundStyle(BondTheme.violet)
                    Text(request.createdAt.relativeTurkish)
                        .font(BondTheme.Typography.caption)
                        .foregroundStyle(BondTheme.muted)
                }
            }
            .foregroundStyle(BondTheme.ink)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(L10n.Feed.openProfile(request.profile.name))
    }

    private func statusLabel(_ status: MeetingRequestStatus) -> some View {
        Text(status.title)
            .font(BondTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, BondTheme.Space.compact)
            .frame(minHeight: 28)
            .background(statusColor(status).opacity(0.1), in: Capsule())
    }

    private func declineButton(for request: MeetingRequest) -> some View {
        AppButton(
            title: L10n.Chat.decline,
            systemName: "xmark",
            role: .secondary,
            enabled: respondingRequestID != request.id
        ) {
            respondingRequestID = request.id
            Task {
                defer { respondingRequestID = nil }
                _ = await appState.respondToMeetingRequest(request.id, accept: false)
            }
        }
    }

    private func acceptButton(for request: MeetingRequest) -> some View {
        AppButton(
            title: L10n.Chat.accept,
            systemName: "checkmark",
            role: .accent,
            enabled: respondingRequestID != request.id
        ) {
            respondingRequestID = request.id
            Task {
                defer { respondingRequestID = nil }
                if let id = await appState.respondToMeetingRequest(request.id, accept: true) {
                    conversationRoute = MeetingConversationRoute(id: id)
                }
            }
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
