import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let conversationID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var showProfile = false
    @State private var replyingTo: Message?
    @State private var activeMessageActions: UUID?
    @State private var showUnmatchAlert = false
    @FocusState private var focused: Bool

    private var conversation: Conversation? { appState.conversations.first { $0.id == conversationID } }

    var body: some View {
        VStack(spacing: 0) {
            if let conversation {
                header(conversation)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            connectionNote
                            ForEach(conversation.messages) { message in
                                MessageBubble(
                                    message: message,
                                    actionsVisible: activeMessageActions == message.id,
                                    react: { reaction in
                                        appState.react(to: message.id, in: conversationID, with: reaction)
                                        activeMessageActions = nil
                                    },
                                    reply: { beginReply(to: message) },
                                    showActions: {
                                        withAnimation(.snappy(duration: 0.2)) {
                                            activeMessageActions = activeMessageActions == message.id ? nil : message.id
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollToBottom(proxy, conversation: conversation, animated: false) }
                    .onChange(of: conversation.messages.count) { _, _ in scrollToBottom(proxy, conversation: conversation, animated: true) }
                }
                composer
            }
        }
        .background(CampusTheme.paper.ignoresSafeArea())
        .foregroundStyle(CampusTheme.ink)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { appState.markConversationRead(conversationID) }
        .alert("Eşleşme sonlandırılsın mı?", isPresented: $showUnmatchAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Eşleşmeyi bitir", role: .destructive) {
                appState.unmatch(conversationID)
                dismiss()
            }
        } message: {
            Text("Sohbet ikinizden de kaldırılır. Karşı taraf engellenmez; ileride tekrar eşleşebilirsiniz.")
        }
        .sheet(isPresented: $showProfile) {
            if let profile = conversation?.profile {
                NavigationStack {
                    SocialPersonDetailView(profile: profile, place: nil)
                }
            }
        }
    }

    private func header(_ conversation: Conversation) -> some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    ProfileMedia(url: conversation.profile.imageURL, data: nil, assetName: conversation.profile.imageAssetName)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                    Text(conversation.profile.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(CampusTheme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(conversation.profile.name) profilini aç")
            Spacer()
            Menu {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.title) { appState.report(conversation.profile, reason: reason) }
                    }
                } label: {
                    Label("Şikâyet et", systemImage: "flag")
                }
                Button("Eşleşmeyi bitir", role: .destructive) { showUnmatchAlert = true }
                Button("Engelle", role: .destructive) {
                    appState.block(conversation.profile)
                    dismiss()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(CampusTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private var connectionNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles").foregroundStyle(CampusTheme.violet)
            Text("İkiniz de sergiler ve canlı müzikle ilgileniyorsunuz.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(CampusTheme.ink.opacity(0.65))
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(CampusTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let replyingTo {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(CampusTheme.violet)
                        .frame(width: 3, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(replyingTo.isMine ? "Kendine yanıt veriyorsun" : "Yanıtlıyorsun")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(CampusTheme.violet)
                        Text(replyingTo.body)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(CampusTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { self.replyingTo = nil } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Yanıtı iptal et")
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.top, 7)
            }

            HStack(alignment: .bottom, spacing: 9) {
                TextField("Mesaj yaz", text: $draft, axis: .vertical)
                    .font(.system(size: 15, design: .rounded))
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(CampusTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CampusTheme.paper)
                        .frame(width: 44, height: 44)
                        .background(canSend ? CampusTheme.ink : CampusTheme.ink.opacity(0.22), in: Circle())
                }
                .disabled(!canSend)
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(CampusTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CampusTheme.hairline).frame(height: 0.5) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        let body = draft
        let reply = replyingTo.map {
            MessageReply(
                messageID: $0.id,
                authorName: $0.isMine ? "Sen" : (conversation?.profile.name ?? ""),
                body: $0.body
            )
        }
        draft = ""
        replyingTo = nil
        Haptics.impact(.light)
        Task { await appState.send(body, in: conversationID, replyTo: reply) }
    }

    private func beginReply(to message: Message) {
        activeMessageActions = nil
        replyingTo = message
        focused = true
        Haptics.impact(.light)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, conversation: Conversation, animated: Bool) {
        guard let id = conversation.messages.last?.id else { return }
        if animated { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .bottom) } }
        else { proxy.scrollTo(id, anchor: .bottom) }
    }
}

private struct MessageBubble: View {
    let message: Message
    let actionsVisible: Bool
    let react: (String) -> Void
    let reply: () -> Void
    let showActions: () -> Void
    private let reactions = ["❤️", "😂", "😮", "😢", "👍"]
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            if message.isMine { Spacer(minLength: 62) }

            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CampusTheme.violet)
                .frame(width: min(dragOffset, 44), height: 44)
                .opacity(min(dragOffset / 44, 1))

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if actionsVisible {
                    quickActions
                        .transition(.scale(scale: 0.85, anchor: message.isMine ? .trailing : .leading).combined(with: .opacity))
                }

                VStack(alignment: message.isMine ? .trailing : .leading, spacing: 6) {
                    if let quoted = message.replyTo {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quoted.authorName)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(message.isMine ? CampusTheme.acid : CampusTheme.violet)
                            Text(quoted.body)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(2)
                                .foregroundStyle(message.isMine ? CampusTheme.paper.opacity(0.66) : CampusTheme.muted)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: 230, alignment: .leading)
                        .background(message.isMine ? .white.opacity(0.1) : CampusTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Text(message.body)
                        .font(.system(size: 15, design: .rounded))
                        .lineSpacing(3)
                    Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(message.isMine ? CampusTheme.paper.opacity(0.52) : CampusTheme.muted)
                }
                .foregroundStyle(message.isMine ? CampusTheme.paper : CampusTheme.ink)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(message.isMine ? CampusTheme.ink : CampusTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if !message.isMine {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CampusTheme.hairline)
                    }
                }
                .offset(x: dragOffset)
                .onLongPressGesture(minimumDuration: 0.35) {
                    Haptics.impact(.light)
                    showActions()
                }
                .simultaneousGesture(replyGesture)
                .accessibilityAction(named: "Yanıtla", reply)

                if let reaction = message.reaction {
                    Button { react(reaction) } label: {
                        Text(reaction)
                            .font(.system(size: 14))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(CampusTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(CampusTheme.hairline))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(reaction) tepkisini kaldır")
                }
            }
            if !message.isMine { Spacer(minLength: 62) }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 2) {
            ForEach(reactions, id: \.self) { reaction in
                Button { react(reaction) } label: {
                    Text(reaction)
                        .font(.system(size: 19))
                        .frame(width: 38, height: 38)
                        .background(message.reaction == reaction ? CampusTheme.violet.opacity(0.14) : .clear, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(reaction) tepkisi")
            }
            Rectangle().fill(CampusTheme.hairline).frame(width: 1, height: 24)
            Button(action: reply) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Yanıtla")
        }
        .padding(4)
        .foregroundStyle(CampusTheme.ink)
        .background(CampusTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(CampusTheme.hairline))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }

    private var replyGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard value.translation.width > 0,
                      abs(value.translation.height) < abs(value.translation.width) else { return }
                dragOffset = min(value.translation.width, 58)
            }
            .onEnded { value in
                let shouldReply = dragOffset >= 52 || value.predictedEndTranslation.width >= 80
                withAnimation(.snappy(duration: 0.2)) { dragOffset = 0 }
                if shouldReply { reply() }
            }
    }
}
