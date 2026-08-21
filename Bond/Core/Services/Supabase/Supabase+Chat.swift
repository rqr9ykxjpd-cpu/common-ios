import Foundation
import Supabase

extension SupabaseProductService {
    func fetchConversations() async throws -> [Conversation] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let matches: [MatchRow] = try await client
            .from("matches")
            .select("id,user_a,user_b,created_at,user_a_profile:profiles!matches_user_a_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),user_b_profile:profiles!matches_user_b_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)")
            .is("unmatched_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value

        let peerAvatarPaths = matches.compactMap { $0.peer(for: userID).avatarPath }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: peerAvatarPaths)

        var conversations: [Conversation] = []
        for match in matches {
            let rows: [MessageRow] = try await client
                .from("messages")
                .select("id,match_id,sender_id,body,reply_to_id,reaction,created_at,read_at,edited_at")
                .eq("match_id", value: match.id)
                .order("created_at", ascending: true)
                .execute()
                .value
            let peer = match.peer(for: userID)
            let messages = rows.map { $0.message(currentUserID: userID, allRows: rows, peerName: peer.name) }
            conversations.append(Conversation(
                id: match.id,
                profile: peer.studentProfile(avatarURL: peer.avatarPath.flatMap { urlMap[$0] }),
                messages: messages,
                updatedAt: messages.last?.sentAt ?? match.createdAt,
                unreadCount: rows.filter { $0.senderID != userID && $0.readAt == nil }.count
            ))
        }
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func sendMessage(_ message: Message, matchID: UUID) async throws -> Message {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let payload = MessageInsert(
            id: message.id,
            matchID: matchID,
            senderID: userID,
            body: message.body,
            replyToID: message.replyTo?.messageID
        )
        let row: MessageRow = try await client
            .from("messages")
            .insert(payload)
            .select("id,match_id,sender_id,body,reply_to_id,reaction,created_at,read_at,edited_at")
            .single()
            .execute()
            .value
        // Sunucu satırı id, created_at ve reaction için yetkilidir. `replyTo` ise istemcide
        // zaten çözümlenmiş durumda — tek satırlık listede lookup yapmak onu daima nil'e
        // düşürdüğü için gönderilen mesajın yanıt bağlamını doğrudan koruyoruz.
        return Message(
            id: row.id,
            body: row.body,
            isMine: row.senderID == userID,
            sentAt: row.createdAt,
            reaction: row.reaction,
            replyTo: message.replyTo
        )
    }

    func markConversationRead(matchID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client
            .from("messages")
            .update(MessageReadUpdate(readAt: Date()))
            .eq("match_id", value: matchID)
            .neq("sender_id", value: userID)
            .is("read_at", value: nil)
            .execute()
    }

    func deleteMessage(_ messageID: UUID) async throws {
        try await client.from("messages")
            .delete(returning: .minimal)
            .eq("id", value: messageID)
            .execute()
    }

    func editMessage(_ messageID: UUID, body: String) async throws {
        try await client.from("messages")
            .update(MessageEdit(body: body, editedAt: Date()), returning: .minimal)
            .eq("id", value: messageID)
            .execute()
    }

    func setStoryLiked(_ storyID: UUID, liked: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if liked {
            // Beğeninin varlığı bilginin tamamı; güncellenecek sütun yok, dolayısıyla
            // DO NOTHING yeterli (tabloda update yetkisi de yok).
            try await client.from("story_likes")
                .upsert(StoryLikeInsert(storyID: storyID, likerID: userID),
                        returning: .minimal, ignoreDuplicates: true)
                .execute()
        } else {
            try await client.from("story_likes")
                .delete(returning: .minimal)
                .eq("story_id", value: storyID)
                .eq("liker_id", value: userID)
                .execute()
        }
    }

    func isStoryLiked(_ storyID: UUID) async throws -> Bool {
        guard let userID = currentUserID else { return false }
        let rows: [StoryLikeRow] = try await client.from("story_likes")
            .select("story_id")
            .eq("story_id", value: storyID)
            .eq("liker_id", value: userID)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    func setMessageReaction(messageID: UUID, reaction: String?) async throws {
        try await client
            .rpc("set_message_reaction", params: MessageReactionParams(messageID: messageID, reaction: reaction))
            .execute()
    }
    func messageStream() -> AsyncStream<RealtimeMessage> {
        AsyncStream { continuation in
            let task = Task {
                guard let userID = currentUserID else {
                    continuation.finish()
                    return
                }

                // Üst üste başarısız denemelerde bekleme süresi katlanarak artıyor;
                // ağ gerçekten yoksa saniyede bir denemenin anlamı yok.
                let ilkBekleme: UInt64 = 1_000_000_000
                let enUzunBekleme: UInt64 = 30_000_000_000
                var bekleme = ilkBekleme

                while !Task.isCancelled {
                    let channel = client.channel("messages-\(userID.uuidString.lowercased())")
                    let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
                    // Güncellemeler de dinleniyor: mesaj tepkisi (kalp, emoji) satırı
                    // güncelliyor, eklemiyor. Yalnızca eklemeler dinlendiği için karşı
                    // taraf tepkiyi ancak uygulamayı yeniden yükleyince görüyordu.
                    let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "messages")
                    do {
                        try await channel.subscribeWithError()
                        bekleme = ilkBekleme
                        await withTaskGroup(of: Void.self) { grup in
                            grup.addTask {
                                for await insertion in insertions {
                                    guard let row = try? insertion.decodeRecord(as: MessageRow.self, decoder: Self.decoder) else { continue }
                                    continuation.yield(RealtimeMessage(
                                        matchID: row.matchID, id: row.id, senderID: row.senderID,
                                        body: row.body, replyToID: row.replyToID,
                                        reaction: row.reaction, createdAt: row.createdAt
                                    ))
                                }
                            }
                            grup.addTask {
                                for await update in updates {
                                    guard let row = try? update.decodeRecord(as: MessageRow.self, decoder: Self.decoder) else { continue }
                                    continuation.yield(RealtimeMessage(
                                        matchID: row.matchID, id: row.id, senderID: row.senderID,
                                        body: row.body, replyToID: row.replyToID,
                                        reaction: row.reaction, createdAt: row.createdAt
                                    ))
                                }
                            }
                        }
                    } catch {
                        // Bağlanılamadı; aşağıdaki beklemeden sonra tekrar denenecek.
                    }
                    await client.removeChannel(channel)
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: bekleme)
                    bekleme = min(bekleme * 2, enUzunBekleme)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// `post_likes`, `saved_posts` ve `club_members` tablolarında `authenticated`
    /// rolüne UPDATE yetkisi verilmemiş. Varsayılan `upsert` ON CONFLICT DO UPDATE
    /// ürettiği ve Postgres bu yetkiyi çakışma olmasa bile baştan aradığı için bu
    /// çağrılar her seferinde izin hatasıyla dönüyordu. Satırın kendisi bilginin
    /// tamamı olduğundan güncellenecek bir şey yok: `ignoreDuplicates` ile
    func unmatch(_ matchID: UUID) async throws {
        try await client.rpc("unmatch", params: UnmatchParams(matchUUID: matchID)).execute()
    }
    func sendMessageRequest(to profileID: UUID, body: String, storyID: UUID?) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("message_requests")
            .insert(MessageRequestInsert(senderID: userID, recipientID: profileID,
                                         body: body, storyID: storyID), returning: .minimal)
            .execute()
    }

    func fetchMessageRequests() async throws -> [MessageRequest] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [MessageRequestRow] = try await client
            .from("message_requests")
            .select("""
            id,sender_id,recipient_id,body,status,created_at,\
            sender:profiles!message_requests_sender_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            recipient:profiles!message_requests_recipient_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        let peerPaths = rows.compactMap { $0.senderID == userID ? $0.recipient?.avatarPath : $0.sender?.avatarPath }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: peerPaths)
        return rows.compactMap { row in
            let outgoing = row.senderID == userID
            guard let peer = outgoing ? row.recipient : row.sender else { return nil }
            return MessageRequest(
                id: row.id,
                profile: peer.studentProfile(avatarURL: peer.avatarPath.flatMap { urlMap[$0] }),
                body: row.body,
                direction: outgoing ? .outgoing : .incoming,
                status: row.requestStatus,
                createdAt: row.createdAt
            )
        }
    }

    /// Kabul sunucudaki fonksiyonda: eşleşmeyi kurmak, ilk mesajı sohbete
    /// yazmak ve durumu güncellemek tek işlemde olmak zorunda. Parça parça
    /// yapılsaydı arada kopan bağlantı "kabul edildi ama sohbet yok" bırakırdı.
    func acceptMessageRequest(_ requestID: UUID) async throws -> UUID {
        try await client
            .rpc("accept_message_request", params: MessageRequestAcceptParams(request: requestID))
            .execute()
            .value
    }

    func declineMessageRequest(_ requestID: UUID) async throws {
        try await client.from("message_requests")
            .update(MeetingRequestStatusUpdate(status: "declined"), returning: .minimal)
            .eq("id", value: requestID)
            .execute()
    }
}
