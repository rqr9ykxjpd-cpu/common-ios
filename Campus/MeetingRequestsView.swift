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
                Picker("İstek yönü", selection: $selectedSegment) {
                    Text("Gelen").tag(0)
                    Text("Gönderilen").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, CampusTheme.Space.lg)
                .padding(.vertical, CampusTheme.Space.md)

                if requests.isEmpty {
                    ContentUnavailableView(
                        selectedSegment == 0 ? "Gelen istek yok" : "Gönderilen istek yok",
                        systemImage: "cup.and.saucer",
                        description: Text(selectedSegment == 0 ? "Yeni buluşma istekleri burada görünecek." : "Birinin profilinden buluşma isteği gönderebilirsin.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: CampusTheme.Space.md) {
                            ForEach(requests) { request in
                                requestCard(request)
                            }
                        }
                        .padding(CampusTheme.Space.lg)
                        .padding(.bottom, CampusTheme.Space.xl)
                    }
                }
            }
            .background(CampusTheme.paper.ignoresSafeArea())
            .navigationTitle("Buluşma İstekleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }
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
                NavigationStack { ConversationView(conversationID: route.id) }
            }
        }
    }

    private func requestCard(_ request: MeetingRequest) -> some View {
        VStack(alignment: .leading, spacing: CampusTheme.Space.md) {
            HStack(alignment: .top, spacing: CampusTheme.Space.md) {
                NavigationLink {
                    SocialPersonDetailView(profile: request.profile, place: request.place)
                } label: {
                    HStack(alignment: .top, spacing: CampusTheme.Space.md) {
                        ProfileMedia(url: request.profile.imageURL, data: nil, assetName: request.profile.imageAssetName)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(request.profile.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Label(request.place.name, systemImage: "mappin.and.ellipse")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(CampusTheme.violet)
                            Text(request.createdAt.relativeTurkish)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(CampusTheme.muted)
                        }
                    }
                    .foregroundStyle(CampusTheme.ink)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(request.profile.name) profilini aç")
                Spacer()
                Text(request.status.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor(request.status))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(statusColor(request.status).opacity(0.1), in: Capsule())
            }

            if request.direction == .incoming && request.status == .pending {
                HStack(spacing: CampusTheme.Space.sm) {
                    AppButton(title: "Reddet", systemName: "xmark", role: .secondary) {
                        appState.respondToMeetingRequest(request.id, accept: false)
                    }
                    AppButton(title: "Kabul et", systemName: "checkmark", role: .accent) {
                        appState.respondToMeetingRequest(request.id, accept: true)
                    }
                }
            } else if request.status == .accepted {
                AppButton(title: "Mesaj gönder", systemName: "message.fill", role: .primary) {
                    // Buluşmanın kabul edilmesi eşleşme anlamına gelmiyor;
                    // mesajlaşma eşleşmeye bağlı.
                    if let id = appState.conversationID(for: request.profile) {
                        conversationRoute = MeetingConversationRoute(id: id)
                    } else {
                        appState.show("Yazışmak için Tanış'ta eşleşmeniz gerekiyor.")
                    }
                }
            } else if request.direction == .outgoing && request.status == .pending {
                Text("Karşı taraf yanıtladığında durum burada güncellenecek.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(CampusTheme.muted)
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .padding(CampusTheme.Space.lg)
        .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous)
                .stroke(request.id == initialRequestID ? CampusTheme.violet : CampusTheme.hairline, lineWidth: request.id == initialRequestID ? 1.5 : 1)
        }
    }

    private func statusColor(_ status: MeetingRequestStatus) -> Color {
        switch status {
        case .pending: CampusTheme.coral
        case .accepted: Color.green
        case .declined: CampusTheme.muted
        }
    }
}

private struct MeetingConversationRoute: Identifiable {
    let id: UUID
}
