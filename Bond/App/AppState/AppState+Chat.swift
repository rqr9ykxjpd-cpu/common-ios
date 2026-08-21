import SwiftUI

// MARK: - AppState+Chat
extension AppState {
    /// Sohbet ekranı açık olmasa da eşleşmelerdeki yeni mesajları anlık yakalar —
    /// aksi halde `ConversationView` yalnızca açılış anında bir kerelik yüklüyor,
    /// karşı taraf yazınca ekranda görünmüyor.
    func startMessageListener() {
        guard messageListenerTask == nil else { return }
        messageListenerTask = Task { [weak self] in
            guard let self else { return }
            for await payload in self.service.messageStream() {
                self.handleIncomingMessage(payload)
            }
        }
    }

    func stopMessageListener() {
        messageListenerTask?.cancel()
        messageListenerTask = nil
    }

    func handleIncomingMessage(_ payload: RealtimeMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == payload.matchID }) else {
            // Bilinmeyen bir eşleşmenin ilk mesajı olabilir; sohbet listesini tazele.
            Task { await loadConversations() }
            return
        }
        // Aynı mesaj güncellenmiş olabilir (tepki eklendi/kaldırıldı). Eskiden
        // yinelenen sayılıp atlanıyordu, o yüzden karşı taraf tepkiyi göremiyordu.
        if let mevcut = conversations[index].messages.firstIndex(where: { $0.id == payload.id }) {
            if conversations[index].messages[mevcut].reaction != payload.reaction {
                withAnimation(.snappy) {
                    conversations[index].messages[mevcut].reaction = payload.reaction
                }
            }
            return
        }
        let peerName = conversations[index].profile.name
        let replyTo = payload.replyToID.flatMap { replyID in
            conversations[index].messages.first(where: { $0.id == replyID }).map {
                MessageReply(messageID: $0.id, authorName: $0.isMine ? L10n.Common.you : peerName, body: $0.body)
            }
        }
        let isMine = payload.senderID == currentUserID
        let message = Message(id: payload.id, body: payload.body, isMine: isMine, sentAt: payload.createdAt, reaction: payload.reaction, replyTo: replyTo)
        withAnimation(.snappy) { conversations[index].messages.append(message) }
        conversations[index].updatedAt = message.sentAt
        if !isMine {
            conversations[index].unreadCount += 1
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    /// Uygulama arka plandan öne döndüğünde çağrılır.
    ///
    /// Anlık kanal arka planda kopuyor ve bu sırada gelen mesajlar kaçıyor. Yeniden
    /// bağlanma kendiliğinden oluyor ama kaçırılan mesajları getirmiyor; burada
    /// sunucudan tazeliyoruz. Bildirimler ve story'ler de aynı sebeple yenileniyor.
    func refreshAfterForeground() async {
        guard route == .app else { return }
        await loadConversations()
        await loadNotifications()
        await loadStories()
        try? await service.touchLastActive()
    }
    func block(_ profile: StudentProfile) {
        Task {
            do {
                try await service.blockUser(profile.id)
                profiles.removeAll { $0.id == profile.id }
                conversations.removeAll { $0.profile.id == profile.id }
                posts.removeAll { $0.author.id == profile.id }
                notifications.removeAll { $0.actor?.id == profile.id }
                if selectedConversation?.profile.id == profile.id { selectedConversation = nil }
                show(L10n.Chat.blocked(profile.name))
                Haptics.success()
            } catch {
                showError(error, fallback: L10n.Chat.blockFailed)
            }
        }
    }

    /// Eşleşmeyi sonlandırır. Engellemeden farklı olarak karşı taraf engellenmiş olmaz;
    /// tek çıkış yolu engellemek olduğu için insanlar sıkıldıkları kişiyi engellemek
    /// zorunda kalıyordu.
    func unmatch(_ conversationID: UUID) {
        let previous = conversations
        conversations.removeAll { $0.id == conversationID }
        if selectedConversation?.id == conversationID { selectedConversation = nil }
        Task {
            do {
                try await service.unmatch(conversationID)
                show(L10n.Chat.matchEnded)
                Haptics.success()
            } catch {
                conversations = previous
                showError(error, fallback: L10n.Chat.unmatchFailed)
            }
        }
    }

    func report(_ profile: StudentProfile, reason: ReportReason) {
        Task {
            do {
                try await service.reportUser(profile.id, reason: reason, details: nil)
                show(L10n.Chat.reportReceived)
                Haptics.success()
            } catch {
                showError(error, fallback: L10n.Chat.reportFailed)
            }
        }
    }
    func loadMessageRequests(silently: Bool = false) async {
        do {
            messageRequests = try await service.fetchMessageRequests()
        } catch {
            if !silently { showError(error, fallback: L10n.Chat.requestsLoadFailed) }
        }
    }

    /// Eşleşmeden yanıt. Sohbete değil, karşı tarafa istek olarak gider.
    ///
    /// Sunucu iki durumu ayrı kodlarla reddediyor ve ikisi de kullanıcıya
    /// açıkça söylenmeli: reddedilmiş birine tekrar yazmak ve günlük tavanı
    /// aşmak. "Bir şeyler ters gitti" demek, kullanıcıya tekrar tekrar
    /// denetirdi.
    @discardableResult
    func sendMessageRequest(to profile: StudentProfile, body: String, storyID: UUID? = nil) async -> Bool {
        let metin = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !metin.isEmpty else { return false }
        do {
            try await service.sendMessageRequest(to: profile.id, body: metin, storyID: storyID)
            await loadMessageRequests(silently: true)
            return true
        } catch {
            let ham = String(describing: error)
            if ham.contains("MESSAGE_REQUEST_DECLINED") {
                showError(L10n.Chat.requestIgnored(profile.name))
            } else if ham.contains("MESSAGE_REQUEST_RATE") {
                showError(L10n.Chat.dailyLimit)
            } else if ham.contains("message_requests_pending_idx") || ham.contains("duplicate key") {
                showError(L10n.Chat.alreadyRequested(profile.name))
            } else {
                showError(error, fallback: L10n.Chat.requestSendFailed)
            }
            return false
        }
    }

    /// Kabul: sunucu eşleşmeyi kurup ilk mesajı sohbete yazıyor ve eşleşmenin
    /// kimliğini dönüyor. Dönen kimlikle sohbeti açabiliyoruz.
    func acceptMessageRequest(_ requestID: UUID) async -> UUID? {
        do {
            let eslesme = try await service.acceptMessageRequest(requestID)
            await loadMessageRequests(silently: true)
            await loadConversations()
            Haptics.success()
            return eslesme
        } catch {
            showError(error, fallback: L10n.Chat.acceptFailed)
            return nil
        }
    }

    func declineMessageRequest(_ requestID: UUID) async {
        // İyimser: satır listeden hemen kalkıyor. Reddetmek geri alınabilir bir
        // şey değil, kullanıcının beklemesi için sebep yok.
        let onceki = messageRequests
        messageRequests.removeAll { $0.id == requestID }
        do {
            try await service.declineMessageRequest(requestID)
        } catch {
            messageRequests = onceki
            showError(error, fallback: L10n.Chat.declineFailed)
        }
    }
    func loadConversations() async {
        isLoadingConversations = true
        defer { isLoadingConversations = false }
        do {
            conversations = try await service.fetchConversations()
        } catch {
            showError(error, fallback: L10n.Chat.loadFailed)
        }
    }

    /// Var olan sohbetin kimliği; yoksa yalnızca gerçek bir eşleşme kimliğiyle
    /// yeni sohbet açılır.
    ///
    /// Eskiden eşleşme yokken rastgele bir kimlikle yerel sohbet uyduruluyordu.
    /// Mesajlaşma eşleşmeye bağlı olduğu için sunucu o sohbete yazılan mesajı
    /// reddediyor, istemci de gönderilemeyen mesajı geri alıyordu: kullanıcı
    /// yazdığı mesajın anında kaybolduğunu görüyordu. En sık yolu kabul edilmiş
    /// bir buluşma isteğinden "Mesaj gönder"e basmaktı — buluşma kabulü eşleşme
    /// anlamına gelmiyor.
    func conversationID(for profile: StudentProfile, matchID: UUID? = nil) -> UUID? {
        if let existing = conversations.first(where: { $0.profile.id == profile.id }) {
            return existing.id
        }
        guard let matchID else { return nil }
        let conversation = Conversation(
            id: matchID,
            profile: profile,
            messages: [],
            updatedAt: .now,
            unreadCount: 0
        )
        conversations.insert(conversation, at: 0)
        return conversation.id
    }
    func markConversationRead(_ conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].unreadCount = 0
        Task {
            do { try await service.markConversationRead(matchID: conversationID) }
            // Kullanıcının başlatmadığı arka plan işi: başarısız olursa okunmadı rozeti
            // kalır, başka bir sonucu yok. Hata göstermek gürültü olurdu; Tanış ekranına
            // yazmak ise büsbütün yanlıştı — orası keşif hataları için.
            catch { }
        }
    }

    func send(_ body: String, in conversationID: UUID, replyTo: MessageReply? = nil) async {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        let message = Message(body: cleanBody, isMine: true, sentAt: .now, replyTo: replyTo)
        withAnimation(.snappy) { conversations[index].messages.append(message) }
        conversations[index].updatedAt = .now
        do {
            let saved = try await service.sendMessage(message, matchID: conversationID)
            guard let refreshedIndex = conversations.firstIndex(where: { $0.id == conversationID }),
                  let messageIndex = conversations[refreshedIndex].messages.firstIndex(where: { $0.id == message.id }) else { return }
            conversations[refreshedIndex].messages[messageIndex] = saved
        } catch {
            if let refreshedIndex = conversations.firstIndex(where: { $0.id == conversationID }) {
                withAnimation(.snappy) {
                    conversations[refreshedIndex].messages.removeAll { $0.id == message.id }
                }
            }
            showError(error, fallback: L10n.Chat.sendFailed)
        }
    }

    /// Kendi mesajını siler. Önce ekrandan kaldırılıyor; sunucu reddederse geri
    /// geliyor ve sebebi söyleniyor.
    func deleteMessage(_ messageID: UUID, in conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == messageID }),
              conversations[index].messages[messageIndex].isMine else { return }
        let kaldirilan = conversations[index].messages[messageIndex]
        // `remove(at:)` çıkardığı öğeyi döndürüyor; sonucu kullanmadığımızı
        // açıkça belirtmezsek derleyici uyarı veriyor.
        withAnimation(.snappy) { _ = conversations[index].messages.remove(at: messageIndex) }
        Haptics.impact(.light)
        Task {
            do { try await service.deleteMessage(messageID) }
            catch {
                if let geri = conversations.firstIndex(where: { $0.id == conversationID }) {
                    withAnimation(.snappy) {
                        conversations[geri].messages.insert(kaldirilan, at: min(messageIndex, conversations[geri].messages.count))
                    }
                }
                showError(error, fallback: L10n.Chat.deleteFailed)
            }
        }
    }

    func editMessage(_ messageID: UUID, in conversationID: UUID, body: String) {
        let temiz = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !temiz.isEmpty,
              let index = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[index].messages.firstIndex(where: { $0.id == messageID }),
              conversations[index].messages[messageIndex].isMine else { return }
        let eski = conversations[index].messages[messageIndex]
        withAnimation(.snappy) {
            conversations[index].messages[messageIndex].body = temiz
            conversations[index].messages[messageIndex].editedAt = .now
        }
        Task {
            do { try await service.editMessage(messageID, body: temiz) }
            catch {
                if let geri = conversations.firstIndex(where: { $0.id == conversationID }),
                   let geriIndex = conversations[geri].messages.firstIndex(where: { $0.id == messageID }) {
                    conversations[geri].messages[geriIndex] = eski
                }
                showError(error, fallback: L10n.Chat.editFailed)
            }
        }
    }
    func react(to messageID: UUID, in conversationID: UUID, with reaction: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let previous = conversations[conversationIndex].messages[messageIndex].reaction
        let updated = previous == reaction ? nil : reaction
        conversations[conversationIndex].messages[messageIndex].reaction = updated
        Task {
            do {
                try await service.setMessageReaction(messageID: messageID, reaction: updated)
                Haptics.impact(.light)
            } catch {
                guard let refreshedConversation = conversations.firstIndex(where: { $0.id == conversationID }),
                      let refreshedMessage = conversations[refreshedConversation].messages.firstIndex(where: { $0.id == messageID }) else { return }
                conversations[refreshedConversation].messages[refreshedMessage].reaction = previous
                showError(error, fallback: L10n.Chat.reactionFailed)
            }
        }
    }
}
