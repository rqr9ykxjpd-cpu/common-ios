import SwiftUI

struct ConversationView: View {
    @Environment(AppState.self) private var appState
    let conversationID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var showProfile = false
    @State private var replyingTo: Message?
    @State private var editingMessage: Message?
    @State private var showPaywall = false
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
                                    edit: { beginEdit(message) },
                                    delete: {
                                        activeMessageActions = nil
                                        appState.deleteMessage(message.id, in: conversationID)
                                    },
                                    canEdit: appState.tier.canEditMessages,
                                    showPaywall: {
                                        activeMessageActions = nil
                                        showPaywall = true
                                    },
                                    showActions: {
                                        withAnimation(.snappy(duration: 0.2)) {
                                            activeMessageActions = activeMessageActions == message.id ? nil : message.id
                                        }
                                    }
                                )
                                .id(message.id)
                                // Mesajlar belirip kaybolurken kayıyor: eskiden aniden
                                // beliriyor ve gönderilemeyip geri alınan mesaj hiç iz
                                // bırakmadan yok oluyordu.
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .scale(scale: 0.85).combined(with: .opacity)
                                ))
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
            } else {
                // Sohbet bulunamadığında ekran tamamen boş kalıyordu. Eşleşme başka bir
                // cihazdan sonlandırılmış ya da liste henüz yüklenmemiş olabilir.
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(BondTheme.ink.opacity(0.35))
                    Text(L10n.Chat.missing)
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.Chat.unmatchedMaybe)
                        .font(.system(size: 13))
                        .foregroundStyle(BondTheme.ink.opacity(0.5))
                    Button(L10n.Common.goBack) { dismiss() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BondTheme.violet)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BondTheme.paper.ignoresSafeArea())
        .foregroundStyle(BondTheme.ink)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { appState.markConversationRead(conversationID) }
        .alert(L10n.Chat.unmatchConfirm, isPresented: $showUnmatchAlert) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Chat.endMatch, role: .destructive) {
                appState.unmatch(conversationID)
                dismiss()
            }
        } message: {
            Text(L10n.Chat.unmatchBody)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
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
            .accessibilityLabel(L10n.Common.back)
            Button { showProfile = true } label: {
                HStack(spacing: 10) {
                    ProfileMedia(url: conversation.profile.imageURL, data: nil, assetName: conversation.profile.imageAssetName)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                    Text(conversation.profile.name)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(BondTheme.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Feed.openProfile(conversation.profile.name))
            Spacer()
            Menu {
                Menu {
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.title) { appState.report(conversation.profile, reason: reason) }
                    }
                } label: {
                    Label(L10n.Common.report, systemImage: "flag")
                }
                Button(L10n.Chat.endMatch, role: .destructive) { showUnmatchAlert = true }
                Button(L10n.Common.block, role: .destructive) {
                    appState.block(conversation.profile)
                    dismiss()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.Chat.options)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(BondTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    /// Karşı tarafla gerçekten paylaşılan ilgi alanları. Bu not daha önce sabit bir
    /// cümleydi ("İkiniz de sergiler ve canlı müzikle ilgileniyorsunuz") ve kimin
    /// sohbeti olursa olsun aynı şeyi yazıyordu — yani doğru olmayan bir bilgi.
    private var sharedInterests: [String] {
        guard let conversation else { return [] }
        let mine = Set(appState.draft.interests)
        return conversation.profile.interests.filter { mine.contains($0) }
    }

    /// Ortak ilgi yoksa hiç gösterilmiyor: uydurma bir yakınlık kurmaktansa susmak daha iyi.
    @ViewBuilder
    private var connectionNote: some View {
        let shared = sharedInterests
        if !shared.isEmpty {
            HStack(spacing: 9) {
                Image(systemName: "sparkles").foregroundStyle(BondTheme.violet)
                Text(connectionText(for: shared))
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.ink.opacity(0.65))
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(BondTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 8)
        }
    }

    private func connectionText(for shared: [String]) -> String {
        let names = shared.map { InterestCatalog.displayName($0).lowercased(with: L10n.appLocale) }
        switch names.count {
        case 1:
            return L10n.Chat.oneShared(names[0])
        case 2:
            return L10n.Chat.twoShared(names[0], names[1])
        default:
            return L10n.Chat.manyShared(names[0], names[1], names.count - 2)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            // Düzenleme şeridi: yazma alanında hangi mesajı değiştirdiğin belli
            // olmazsa, kullanıcı yeni mesaj yazdığını sanır.
            if editingMessage != nil {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(BondTheme.acid)
                        .frame(width: 3, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Chat.editing)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BondTheme.ink)
                        Text(L10n.Chat.editingHint)
                            .font(.system(size: 12))
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        editingMessage = nil
                        draft = ""
                    } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.Chat.cancelEdit)
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }

            if let replyingTo {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(BondTheme.violet)
                        .frame(width: 3, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(replyingTo.isMine ? L10n.Chat.replyingToSelf : L10n.Chat.replying)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(BondTheme.violet)
                        Text(replyingTo.body)
                            .font(.system(size: 12))
                            .foregroundStyle(BondTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { self.replyingTo = nil } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.Chat.cancelReply)
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.top, 7)
            }

            HStack(alignment: .bottom, spacing: 9) {
                TextField(L10n.Chat.placeholder, text: $draft, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...5)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(BondTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(BondTheme.paper)
                        .frame(width: 44, height: 44)
                        .background(canSend ? BondTheme.ink : BondTheme.ink.opacity(0.22), in: Circle())
                }
                .accessibilityLabel(L10n.Common.send)
                .disabled(!canSend)
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(BondTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(BondTheme.hairline).frame(height: 0.5) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func send() {
        guard canSend else { return }
        // Düzenleme modundaysak yeni mesaj göndermiyoruz, mevcut olanı değiştiriyoruz.
        if let duzenlenen = editingMessage {
            appState.editMessage(duzenlenen.id, in: conversationID, body: draft)
            draft = ""
            editingMessage = nil
            Haptics.impact(.light)
            return
        }
        let body = draft
        let reply = replyingTo.map {
            MessageReply(
                messageID: $0.id,
                authorName: $0.isMine ? L10n.Common.you : (conversation?.profile.name ?? ""),
                body: $0.body
            )
        }
        draft = ""
        replyingTo = nil
        Haptics.impact(.light)
        Task { await appState.send(body, in: conversationID, replyTo: reply) }
    }

    /// Mesajın metni yazma alanına alınıyor; gönder düğmesi bu kez düzenliyor.
    /// Ayrı bir düzenleme ekranı açmak, tek satırlık bir düzeltme için ağır.
    private func beginEdit(_ message: Message) {
        activeMessageActions = nil
        replyingTo = nil
        editingMessage = message
        draft = message.body
        focused = true
        Haptics.impact(.light)
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
    let edit: () -> Void
    let delete: () -> Void
    /// Silme ve düzenleme Plus'a özel. Kilitliyken düğmeler gizlenmiyor, tek bir
    /// kilit düğmesine dönüşüyor: özelliğin var olduğunu görmeden kimse
    /// yükseltmeyi düşünmez.
    let canEdit: Bool
    let showPaywall: () -> Void
    let showActions: () -> Void
    private let reactions = ["❤️", "😂", "😮", "😢", "👍"]
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            if message.isMine { Spacer(minLength: 62) }

            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BondTheme.violet)
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
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(message.isMine ? BondTheme.acid : BondTheme.violet)
                            Text(quoted.body)
                                .font(.system(size: 11))
                                .lineLimit(2)
                                .foregroundStyle(message.isMine ? BondTheme.paper.opacity(0.66) : BondTheme.muted)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: 230, alignment: .leading)
                        .background(message.isMine ? BondTheme.paper.opacity(0.13) : BondTheme.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Text(message.body)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                    if message.editedAt != nil {
                        // Renk zaman damgasıyla aynı kuralı izliyor: kendi mesajın
                        // koyu zeminde, karşınınki açık zeminde.
                        Text(L10n.Chat.edited)
                            .font(.system(size: 10))
                            .foregroundStyle(message.isMine ? BondTheme.paper.opacity(0.52) : BondTheme.muted)
                    }
                    Text(message.sentAt.shortTimeTurkish)
                        .font(.system(size: 10))
                        .foregroundStyle(message.isMine ? BondTheme.paper.opacity(0.52) : BondTheme.muted)
                }
                .foregroundStyle(message.isMine ? BondTheme.paper : BondTheme.ink)
                .padding(.horizontal, 13).padding(.vertical, 10)
                .background(message.isMine ? BondTheme.ink : BondTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if !message.isMine {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(BondTheme.hairline)
                    }
                }
                .offset(x: dragOffset)
                .onLongPressGesture(minimumDuration: 0.35) {
                    Haptics.impact(.light)
                    showActions()
                }
                .simultaneousGesture(replyGesture)
                // Çift dokunuşla kalp: tepki vermenin tek yolu menüyü açmaktı.
                .onTapGesture(count: 2) {
                    Haptics.impact(.light)
                    react("❤️")
                }
                .accessibilityAction(named: L10n.Chat.reply, reply)
                .accessibilityAction(named: L10n.Chat.sendHeart) { react("❤️") }

                if let reaction = message.reaction {
                    Button { react(reaction) } label: {
                        Text(reaction)
                            .font(.system(size: 14))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(BondTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(BondTheme.hairline))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(L10n.Chat.removeReaction(reaction))
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
                        .background(message.reaction == reaction ? BondTheme.violet.opacity(0.14) : .clear, in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Chat.addReaction(reaction))
            }
            Rectangle().fill(BondTheme.hairline).frame(width: 1, height: 24)
            Button(action: reply) {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(L10n.Chat.reply)

            // Silme ve düzenleme yalnızca kendi mesajında; sunucu da aynı
            // koşulu uyguluyor, arayüz onu yansıtıyor.
            if message.isMine, !canEdit {
                Button(action: showPaywall) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BondTheme.muted)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Chat.editLocked)
            }

            if message.isMine, canEdit {
                Button(action: edit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Common.edit)

                Button(action: delete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BondTheme.coral)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L10n.Common.delete)
            }
        }
        .padding(4)
        .foregroundStyle(BondTheme.ink)
        .background(BondTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(BondTheme.hairline))
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
