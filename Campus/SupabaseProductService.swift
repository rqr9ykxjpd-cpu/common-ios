import Foundation
import Supabase

struct BackendComment: Sendable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let authorName: String
    let body: String
    let createdAt: Date
}

struct BackendPost: Sendable {
    let id: UUID
    let authorID: UUID
    let authorName: String
    let authorBirthDate: Date
    let authorUniversity: String
    let authorDepartment: String
    let authorYear: String
    let authorBio: String
    let authorVerified: Bool
    let authorAvatarURL: URL?
    let caption: String
    let placeName: String?
    let imageData: Data?
    let createdAt: Date
    let comments: [BackendComment]
    let likeCount: Int
    let liked: Bool
    let saved: Bool
}

enum BackendServiceError: LocalizedError {
    case missingConfiguration
    case missingSession
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Supabase yapılandırması eksik. Project URL ve publishable key eklenmeli."
        case .missingSession:
            "Oturum bulunamadı. Lütfen tekrar giriş yap."
        case .incompleteProfile:
            "Cinsiyet ve tanışma tercihi zorunludur."
        }
    }
}

final class SupabaseProductService: ProductService, @unchecked Sendable {
    private let client: SupabaseClient
    private static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var currentUserID: UUID? { client.auth.currentUser?.id }
    var currentUserEmail: String? { client.auth.currentUser?.email }

    init(configuration: BackendConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }

    func requestOTP(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    /// Supabase, kodu hangi akışın ürettiğine göre farklı tiplerle doğruluyor: ilk kez kayıt
    /// olan kullanıcıya "Confirm signup" e-postası gidiyor ve kod `signup` tipiyle, daha önce
    /// kayıtlı kullanıcıya "Magic Link" gidiyor ve kod `magiclink` tipiyle doğrulanıyor.
    /// Tek tip denemek, kullanıcının ilk kaydında geçerli kodu "geçersiz" göstermeye yol
    /// açtığı için sırayla hepsini deniyoruz.
    func verifyOTP(email: String, code: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let token = code.trimmingCharacters(in: .whitespacesAndNewlines)
        var lastError: Error?
        for type: EmailOTPType in [.email, .signup, .magiclink] {
            do {
                try await client.auth.verifyOTP(email: normalized, token: token, type: type)
                return
            } catch {
                lastError = error
            }
        }
        throw lastError ?? BackendServiceError.missingSession
    }

    func restoreSession() async throws -> UUID? {
        guard client.auth.currentSession != nil else { return nil }
        return try await client.auth.session.user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    func saveProfile(_ draft: ProfileDraft) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        guard let gender = draft.gender,
              let datingPreference = draft.datingPreference else {
            throw BackendServiceError.incompleteProfile
        }
        let prompts = draft.prompts.prefix(3).map {
            ProfilePromptPayload(promptKey: $0.question, answer: $0.answer.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let params = SaveProfileParams(
            profileName: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            profileBirthDate: Self.postgresDateFormatter.string(from: draft.birthDate),
            profileGender: gender.rawValue,
            profileDatingPreference: datingPreference.rawValue,
            profileRelationshipIntent: draft.relationshipIntent.rawValue,
            profileUniversity: draft.university,
            profileDepartment: draft.department.trimmingCharacters(in: .whitespacesAndNewlines),
            profileAcademicYear: draft.year,
            profileBio: draft.bio.trimmingCharacters(in: .whitespacesAndNewlines),
            profileInterests: draft.interests.sorted(),
            profilePrompts: prompts
        )
        try await client.rpc("save_my_profile", params: params).execute()
    }

    func fetchDiscoveryCandidates(filters: DiscoveryFilters, offset: Int, limit: Int) async throws -> [StudentProfile] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let preferences = DiscoveryPreferencesUpsert(
            userID: userID,
            minAge: filters.minimumAge,
            maxAge: filters.maximumAge,
            academicYears: filters.academicYears.sorted(),
            departments: filters.departments.sorted(),
            requireCommonInterest: filters.requiresCommonInterest,
            campusOnly: filters.campusOnly
        )
        try await client.from("discovery_preferences").upsert(preferences).execute()
        let rows: [DiscoveryCandidateRow] = try await client
            .rpc("get_discovery_candidates", params: DiscoveryPageParams(pageLimit: limit, pageOffset: offset))
            .execute()
            .value
        let paths = rows.flatMap { row in (row.avatarPath.map { [$0] } ?? []) + row.galleryPaths }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: paths)
        return rows.map { row in
            row.studentProfile(
                avatarURL: row.avatarPath.flatMap { urlMap[$0] },
                galleryURLs: row.galleryPaths.compactMap { urlMap[$0] }
            )
        }
    }

    func reactToProfile(profileID: UUID, liked: Bool) async throws -> DiscoveryReactionResult {
        let rows: [ReactionResultRow] = try await client
            .rpc("react_to_profile", params: ReactionParams(subject: profileID, reaction: liked ? "like" : "pass"))
            .execute()
            .value
        guard let row = rows.first else { return DiscoveryReactionResult(matched: false, matchID: nil) }
        return DiscoveryReactionResult(matched: row.matched, matchID: row.matchID)
    }

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
                .select("id,match_id,sender_id,body,reply_to_id,reaction,created_at,read_at")
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
            .select("id,match_id,sender_id,body,reply_to_id,reaction,created_at,read_at")
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

    func setMessageReaction(messageID: UUID, reaction: String?) async throws {
        try await client
            .rpc("set_message_reaction", params: MessageReactionParams(messageID: messageID, reaction: reaction))
            .execute()
    }

    func fetchFeed() async throws -> [BackendPost] {
        let rows: [PostRow] = try await client
            .from("posts")
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name))")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.author.avatarPath })
        let userID = currentUserID
        let likeRows: [PostLikeRow] = rows.isEmpty ? [] : ((try? await client
            .from("post_likes")
            .select("post_id,user_id")
            .`in`("post_id", values: rows.map(\.id))
            .execute()
            .value) ?? [])
        let savedIDs: Set<UUID> = rows.isEmpty ? [] : Set(((try? await client
            .from("saved_posts")
            .select("post_id")
            .`in`("post_id", values: rows.map(\.id))
            .execute()
            .value) as [SavedPostRow]? ?? []).map(\.postID))
        var posts: [BackendPost] = []
        for row in rows {
            var imageData: Data?
            if let mediaPath = row.mediaPath {
                imageData = try? await client.storage.from("post-media").download(path: mediaPath)
            }
            let authorAvatarURL = row.author.avatarPath.flatMap { avatarURLs[$0] }
            let postLikes = likeRows.filter { $0.postID == row.id }
            posts.append(row.backendPost(
                imageData: imageData,
                authorAvatarURL: authorAvatarURL,
                likeCount: postLikes.count,
                liked: userID.map { id in postLikes.contains { $0.userID == id } } ?? false,
                saved: savedIDs.contains(row.id)
            ))
        }
        return posts
    }

    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        var mediaPath: String?
        if let imageData {
            let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await client.storage
                .from("post-media")
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            mediaPath = path
        }
        let payload = PostInsert(
            authorID: userID,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            placeName: placeName,
            mediaPath: mediaPath
        )
        let row: PostRow = try await client
            .from("posts")
            .insert(payload)
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name))")
            .single()
            .execute()
            .value
        var authorAvatarURL: URL?
        if let path = row.author.avatarPath {
            authorAvatarURL = try? await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3600)
        }
        return row.backendPost(imageData: imageData, authorAvatarURL: authorAvatarURL, likeCount: 0, liked: false, saved: false)
    }

    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let payload = CommentInsert(postID: postID, authorID: userID, body: body)
        let row: CommentRow = try await client
            .from("comments")
            .insert(payload)
            .select("id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name)")
            .single()
            .execute()
            .value
        return row.backendComment
    }

    func deletePost(_ postID: UUID) async throws {
        try await client.from("posts").delete(returning: .minimal).eq("id", value: postID).execute()
    }

    func deleteComment(_ commentID: UUID) async throws {
        try await client.from("comments").delete(returning: .minimal).eq("id", value: commentID).execute()
    }

    func fetchMyProfile() async throws -> ProfileDraft? {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [MyProfileRow] = try await client.rpc("get_my_profile").execute().value
        guard let row = rows.first else { return nil }
        var draft = ProfileDraft()
        draft.name = row.name
        draft.birthDate = row.birthDate
        draft.gender = ProfileGender(rawValue: row.gender)
        draft.datingPreference = DatingPreference(rawValue: row.datingPreference)
        draft.relationshipIntent = RelationshipIntent(rawValue: row.relationshipIntent) ?? .both
        draft.university = row.university
        draft.department = row.department
        draft.year = row.academicYear
        draft.bio = row.bio
        draft.interests = Set(row.interests)
        if !row.promptKeys.isEmpty {
            draft.prompts = zip(row.promptKeys, row.promptAnswers).map { ProfilePrompt(question: $0.0, answer: $0.1) }
        }
        var filters = DiscoveryFilters()
        filters.minimumAge = row.minAge
        filters.maximumAge = row.maxAge
        filters.academicYears = Set(row.academicYears)
        filters.departments = Set(row.departments)
        filters.requiresCommonInterest = row.requireCommonInterest
        filters.campusOnly = row.campusOnly
        draft.discoveryFilters = filters
        return draft
    }

    func fetchMyProfilePhotos() async throws -> ProfilePhotosResult {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let profile: ProfileMediaRow = try await client
            .from("profiles")
            .select("avatar_path")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        let gallery: [ProfilePhotoRow] = try await client
            .from("profile_photos")
            .select("storage_path,position")
            .eq("profile_id", value: userID)
            .order("position", ascending: true)
            .execute()
            .value
        var avatarURL: URL?
        if let path = profile.avatarPath {
            avatarURL = try await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3_600)
        }
        var galleryURLs: [URL] = []
        for photo in gallery {
            galleryURLs.append(try await client.storage.from("profile-photos").createSignedURL(path: photo.storagePath, expiresIn: 3_600))
        }
        return ProfilePhotosResult(avatarURL: avatarURL, galleryURLs: galleryURLs)
    }

    func updateAvatar(_ imageData: Data?) async throws -> URL? {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let profile: ProfileMediaRow = try await client
            .from("profiles")
            .select("avatar_path")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        guard let imageData else {
            try await client.from("profiles").update(AvatarPathUpdate(path: nil), returning: .minimal).eq("id", value: userID).execute()
            if let oldPath = profile.avatarPath {
                _ = try? await client.storage.from("profile-photos").remove(paths: [oldPath])
            }
            return nil
        }

        let path = "\(userID.uuidString.lowercased())/avatar-\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from("profile-photos").upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        do {
            try await client.from("profiles").update(AvatarPathUpdate(path: path), returning: .minimal).eq("id", value: userID).execute()
        } catch {
            _ = try? await client.storage.from("profile-photos").remove(paths: [path])
            throw error
        }
        if let oldPath = profile.avatarPath, oldPath != path {
            _ = try? await client.storage.from("profile-photos").remove(paths: [oldPath])
        }
        return try await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3_600)
    }

    func updateGallery(_ images: [Data]) async throws -> [URL] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let limitedImages = Array(images.prefix(6))
        let oldPhotos: [ProfilePhotoRow] = try await client
            .from("profile_photos")
            .select("storage_path,position")
            .eq("profile_id", value: userID)
            .execute()
            .value
        var newPaths: [String] = []
        do {
            for image in limitedImages {
                let path = "\(userID.uuidString.lowercased())/gallery-\(UUID().uuidString.lowercased()).jpg"
                try await client.storage.from("profile-photos").upload(path, data: image, options: FileOptions(contentType: "image/jpeg"))
                newPaths.append(path)
            }
            try await client.from("profile_photos").delete(returning: .minimal).eq("profile_id", value: userID).execute()
            if !newPaths.isEmpty {
                let rows = newPaths.enumerated().map { ProfilePhotoInsert(profileID: userID, storagePath: $0.element, position: $0.offset) }
                try await client.from("profile_photos").insert(rows).execute()
            }
        } catch {
            if !newPaths.isEmpty { _ = try? await client.storage.from("profile-photos").remove(paths: newPaths) }
            throw error
        }
        let obsoletePaths = oldPhotos.map(\.storagePath).filter { !newPaths.contains($0) }
        if !obsoletePaths.isEmpty { _ = try? await client.storage.from("profile-photos").remove(paths: obsoletePaths) }
        var urls: [URL] = []
        for path in newPaths {
            urls.append(try await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3_600))
        }
        return urls
    }

    func blockUser(_ profileID: UUID) async throws {
        // Runs as a security definer RPC so the same call also ends any live match —
        // direct client writes to `matches` aren't granted, and leaving a severed
        // block's match untouched would let the conversation reappear after a refresh.
        try await client.rpc("block_user", params: BlockParams(target: profileID)).execute()
    }

    func unblockUser(_ profileID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("blocks").delete(returning: .minimal)
            .eq("blocker_id", value: userID)
            .eq("blocked_id", value: profileID)
            .execute()
    }

    func reportUser(_ profileID: UUID, reason: ReportReason, details: String?) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let cleanDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.from("reports").insert(ReportInsert(
            reporterID: userID,
            reportedID: profileID,
            reason: reason.rawValue,
            details: cleanDetails?.isEmpty == true ? nil : cleanDetails
        )).execute()
    }

    // RLS on `messages` (is_match_member) already limits Postgres Changes delivery to rows
    // this user could SELECT, so subscribing to every insert on the table without a match_id
    // filter still only ever streams this user's own conversations.
    func messageStream() -> AsyncStream<RealtimeMessage> {
        AsyncStream { continuation in
            let task = Task {
                guard let userID = currentUserID else {
                    continuation.finish()
                    return
                }
                let channel = client.channel("messages-\(userID.uuidString.lowercased())")
                let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "messages")
                do {
                    try await channel.subscribeWithError()
                } catch {
                    continuation.finish()
                    return
                }
                for await insertion in insertions {
                    guard let row = try? insertion.decodeRecord(as: MessageRow.self, decoder: PostgrestClient.Configuration.jsonDecoder) else { continue }
                    continuation.yield(RealtimeMessage(
                        matchID: row.matchID,
                        id: row.id,
                        senderID: row.senderID,
                        body: row.body,
                        replyToID: row.replyToID,
                        reaction: row.reaction,
                        createdAt: row.createdAt
                    ))
                }
                await client.removeChannel(channel)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func setPostLiked(_ postID: UUID, liked: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if liked {
            try await client.from("post_likes")
                .upsert(PostLikeInsert(postID: postID, userID: userID), returning: .minimal)
                .execute()
        } else {
            try await client.from("post_likes")
                .delete(returning: .minimal)
                .eq("post_id", value: postID)
                .eq("user_id", value: userID)
                .execute()
        }
    }

    func setPostSaved(_ postID: UUID, saved: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if saved {
            try await client.from("saved_posts")
                .upsert(SavedPostInsert(postID: postID, userID: userID), returning: .minimal)
                .execute()
        } else {
            try await client.from("saved_posts")
                .delete(returning: .minimal)
                .eq("post_id", value: postID)
                .eq("user_id", value: userID)
                .execute()
        }
    }

    func fetchNotifications() async throws -> [BackendNotification] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [NotificationRow] = try await client
            .from("notifications")
            .select("id,kind,title,body,actor_id,match_id,is_read,created_at,actor:profiles!notifications_actor_id_fkey(name,avatar_path)")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.actor?.avatarPath })
        return rows.map { row in
            BackendNotification(
                id: row.id,
                kind: row.appKind,
                title: row.title,
                body: row.body,
                actorID: row.actorID,
                actorName: row.actor?.name,
                actorAvatarURL: row.actor?.avatarPath.flatMap { avatarURLs[$0] },
                matchID: row.matchID,
                isRead: row.isRead,
                createdAt: row.createdAt
            )
        }
    }

    func markNotificationRead(_ notificationID: UUID) async throws {
        try await client.from("notifications")
            .update(NotificationReadUpdate(isRead: true), returning: .minimal)
            .eq("id", value: notificationID)
            .execute()
    }

    func markAllNotificationsRead() async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("notifications")
            .update(NotificationReadUpdate(isRead: true), returning: .minimal)
            .eq("user_id", value: userID)
            .eq("is_read", value: false)
            .execute()
    }

    func registerDeviceToken(_ token: String) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("device_tokens")
            .upsert(DeviceTokenUpsert(userID: userID, token: token, platform: "ios"), returning: .minimal)
            .execute()
    }

    func fetchPlaces() async throws -> [CampusPlace] {
        let rows: [PlaceRow] = try await client
            .from("places")
            .select("id,name,area")
            .order("name")
            .execute()
            .value
        return rows.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) }
    }

    func fetchMeetingRequests() async throws -> [MeetingRequest] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [MeetingRequestRow] = try await client
            .from("meeting_requests")
            .select("""
            id,requester_id,recipient_id,place_id,status,created_at,\
            place:places!meeting_requests_place_id_fkey(id,name,area),\
            requester:profiles!meeting_requests_requester_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            recipient:profiles!meeting_requests_recipient_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        // Karşı taraf, isteği kimin gönderdiğine göre değişir: gelen istekte gönderen,
        // giden istekte alıcı gösterilmeli.
        let peerPaths = rows.compactMap { $0.requesterID == userID ? $0.recipient?.avatarPath : $0.requester?.avatarPath }
        let urlMap = await signedURLs(bucket: "profile-photos", paths: peerPaths)
        return rows.compactMap { row in
            let outgoing = row.requesterID == userID
            guard let peer = outgoing ? row.recipient : row.requester, let place = row.place else { return nil }
            return MeetingRequest(
                id: row.id,
                profile: peer.studentProfile(avatarURL: peer.avatarPath.flatMap { urlMap[$0] }),
                place: CampusPlace(id: place.id, name: place.name, area: place.area),
                direction: outgoing ? .outgoing : .incoming,
                status: row.meetingStatus,
                createdAt: row.createdAt
            )
        }
    }

    func sendMeetingRequest(to profileID: UUID, placeID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("meeting_requests")
            .insert(MeetingRequestInsert(requesterID: userID, recipientID: profileID, placeID: placeID), returning: .minimal)
            .execute()
    }

    func respondToMeetingRequest(_ requestID: UUID, accept: Bool) async throws {
        try await client.from("meeting_requests")
            .update(MeetingRequestStatusUpdate(status: accept ? "accepted" : "declined"), returning: .minimal)
            .eq("id", value: requestID)
            .execute()
    }

    func touchLastActive() async throws {
        try await client.rpc("touch_last_active").execute()
    }

    func fetchStories() async throws -> [CampusStory] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [StoryRow] = try await client
            .from("stories")
            .select("""
            id,author_id,media_path,caption,place_id,created_at,expires_at,\
            author:profiles!stories_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            place:places!stories_place_id_fkey(id,name,area),\
            story_views(viewer_id)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        let mediaURLs = await signedURLs(bucket: "story-media", paths: rows.map(\.mediaPath))
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.author?.avatarPath })
        return rows.compactMap { row in
            guard let author = row.author else { return nil }
            return CampusStory(
                id: row.id,
                author: author.studentProfile(avatarURL: author.avatarPath.flatMap { avatarURLs[$0] }),
                imageURL: mediaURLs[row.mediaPath],
                caption: row.caption,
                place: row.place.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) },
                viewed: row.storyViews?.contains { $0.viewerID == userID } ?? false,
                isMine: row.authorID == userID,
                expiresAt: row.expiresAt
            )
        }
    }

    func publishStory(imageData: Data, caption: String, placeID: UUID?) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from("story-media")
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        do {
            try await client.from("stories")
                .insert(StoryInsert(authorID: userID, mediaPath: path,
                                    caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                                    placeID: placeID), returning: .minimal)
                .execute()
        } catch {
            // Satır eklenemezse yüklenen dosya sahipsiz kalmasın.
            _ = try? await client.storage.from("story-media").remove(paths: [path])
            throw error
        }
    }

    func deleteStory(_ storyID: UUID) async throws {
        try await client.from("stories").delete(returning: .minimal).eq("id", value: storyID).execute()
    }

    func markStoryViewed(_ storyID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try await client.from("story_views")
            .upsert(StoryViewUpsert(storyID: storyID, viewerID: userID, lastViewedAt: Date()), returning: .minimal)
            .execute()
    }

    func setVisiblePlace(_ placeID: UUID?) async throws {
        try await client.rpc("set_visible_place", params: VisiblePlaceParams(targetPlace: placeID)).execute()
    }

    func fetchPeopleAtPlace(_ placeID: UUID) async throws -> [StudentProfile] {
        let rows: [PlacePersonRow] = try await client
            .rpc("get_people_at_place", params: PlacePeopleParams(targetPlace: placeID))
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { row in
            let age = max(18, Calendar.current.dateComponents([.year], from: row.birthDate, to: .now).year ?? 18)
            return StudentProfile(
                id: row.id, name: row.name, age: age, university: row.university,
                department: row.department, year: row.academicYear, bio: row.bio,
                interests: row.interests,
                imageURL: row.avatarPath.flatMap { avatarURLs[$0] },
                compatibility: 0, isVerified: row.isVerified,
                relationshipIntent: row.relationshipIntent, activeLabel: row.activeLabel
            )
        }
    }

    func fetchClubs() async throws -> (clubs: [CampusClub], joinedIDs: Set<UUID>) {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [ClubRow] = try await client
            .from("clubs")
            .select("id,name,summary,icon,next_event,accent_hex,place:places!clubs_place_id_fkey(id,name,area),club_members(user_id)")
            .order("name")
            .execute()
            .value
        let clubs = rows.map { row in
            CampusClub(
                id: row.id,
                name: row.name,
                summary: row.summary,
                icon: row.icon,
                memberCount: row.members?.count ?? 0,
                nextEvent: row.nextEvent,
                meetingPlace: row.place.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) },
                accentHex: row.accentHex
            )
        }
        let joined = Set(rows.filter { $0.members?.contains { $0.userID == userID } ?? false }.map(\.id))
        return (clubs, joined)
    }

    func setClubMembership(_ clubID: UUID, joined: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if joined {
            try await client.from("club_members")
                .upsert(ClubMemberInsert(clubID: clubID, userID: userID), returning: .minimal)
                .execute()
        } else {
            try await client.from("club_members")
                .delete(returning: .minimal)
                .eq("club_id", value: clubID)
                .eq("user_id", value: userID)
                .execute()
        }
    }

    func fetchStoryViews(_ storyID: UUID) async throws -> [StoryViewRecord] {
        let rows: [StoryViewRow] = try await client
            .from("story_views")
            .select("viewer_id,view_count,last_viewed_at,viewer:profiles!story_views_viewer_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified)")
            .eq("story_id", value: storyID)
            .order("last_viewed_at", ascending: false)
            .execute()
            .value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.viewer?.avatarPath })
        return rows.compactMap { row in
            guard let viewer = row.viewer else { return nil }
            return StoryViewRecord(
                viewer: viewer.studentProfile(avatarURL: viewer.avatarPath.flatMap { avatarURLs[$0] }),
                viewCount: row.viewCount,
                lastViewedAt: row.lastViewedAt
            )
        }
    }

    private func signedURLs(bucket: String, paths: [String]) async -> [String: URL] {
        let uniquePaths = Array(Set(paths))
        guard !uniquePaths.isEmpty else { return [:] }
        guard let results = try? await client.storage.from(bucket).createSignedURLs(paths: uniquePaths, expiresIn: 3_600) else { return [:] }
        var map: [String: URL] = [:]
        for result in results {
            if case let .success(path, url) = result { map[path] = url }
        }
        return map
    }
}

private struct VisiblePlaceParams: Encodable {
    let targetPlace: UUID?
    enum CodingKeys: String, CodingKey { case targetPlace = "target_place" }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let targetPlace { try container.encode(targetPlace, forKey: .targetPlace) }
        else { try container.encodeNil(forKey: .targetPlace) }
    }
}

private struct PlacePeopleParams: Encodable {
    let targetPlace: UUID
    enum CodingKeys: String, CodingKey { case targetPlace = "target_place" }
}

private struct PlacePersonRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    let relationshipIntent: RelationshipIntent
    let interests: [String]
    let activeLabel: String

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case relationshipIntent = "relationship_intent"
        case activeLabel = "active_label"
    }
}

private struct ClubMemberIDRow: Decodable {
    let userID: UUID
    enum CodingKeys: String, CodingKey { case userID = "user_id" }
}

private struct ClubRow: Decodable {
    let id: UUID
    let name: String
    let summary: String
    let icon: String
    let nextEvent: String
    let accentHex: String
    let place: PlaceRow?
    let members: [ClubMemberIDRow]?

    enum CodingKeys: String, CodingKey {
        case id, name, summary, icon, place
        case nextEvent = "next_event"
        case accentHex = "accent_hex"
        case members = "club_members"
    }
}

private struct ClubMemberInsert: Encodable {
    let clubID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case userID = "user_id"
    }
}

private struct StoryViewerIDRow: Decodable {
    let viewerID: UUID
    enum CodingKeys: String, CodingKey { case viewerID = "viewer_id" }
}

private struct StoryRow: Decodable {
    let id: UUID
    let authorID: UUID
    let mediaPath: String
    let caption: String
    let createdAt: Date
    let expiresAt: Date
    let author: SupabaseProfileRow?
    let place: PlaceRow?
    let storyViews: [StoryViewerIDRow]?

    enum CodingKeys: String, CodingKey {
        case id, caption, author, place
        case authorID = "author_id"
        case mediaPath = "media_path"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case storyViews = "story_views"
    }
}

private struct StoryInsert: Encodable {
    let authorID: UUID
    let mediaPath: String
    let caption: String
    let placeID: UUID?
    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case mediaPath = "media_path"
        case caption
        case placeID = "place_id"
    }
}

private struct StoryViewUpsert: Encodable {
    let storyID: UUID
    let viewerID: UUID
    let lastViewedAt: Date
    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case viewerID = "viewer_id"
        case lastViewedAt = "last_viewed_at"
    }
}

private struct StoryViewRow: Decodable {
    let viewCount: Int
    let lastViewedAt: Date
    let viewer: SupabaseProfileRow?
    enum CodingKeys: String, CodingKey {
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
        case viewer
    }
}

private struct PlaceRow: Decodable {
    let id: UUID
    let name: String
    let area: String
}

private struct MeetingRequestRow: Decodable {
    let id: UUID
    let requesterID: UUID
    let recipientID: UUID
    let status: String
    let createdAt: Date
    let place: PlaceRow?
    let requester: SupabaseProfileRow?
    let recipient: SupabaseProfileRow?

    enum CodingKeys: String, CodingKey {
        case id, status, place, requester, recipient
        case requesterID = "requester_id"
        case recipientID = "recipient_id"
        case createdAt = "created_at"
    }

    var meetingStatus: MeetingRequestStatus {
        switch status {
        case "accepted": .accepted
        case "declined": .declined
        default: .pending
        }
    }
}

private struct MeetingRequestInsert: Encodable {
    let requesterID: UUID
    let recipientID: UUID
    let placeID: UUID
    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case recipientID = "recipient_id"
        case placeID = "place_id"
    }
}

private struct MeetingRequestStatusUpdate: Encodable {
    let status: String
}

private struct NotificationActorRow: Decodable {
    let name: String
    let avatarPath: String?
    enum CodingKeys: String, CodingKey {
        case name
        case avatarPath = "avatar_path"
    }
}

private struct NotificationRow: Decodable {
    let id: UUID
    let kind: String
    let title: String
    let body: String
    let actorID: UUID?
    let matchID: UUID?
    let isRead: Bool
    let createdAt: Date
    let actor: NotificationActorRow?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, actor
        case actorID = "actor_id"
        case matchID = "match_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    var appKind: AppNotificationKind {
        switch kind {
        case "like": .like
        case "comment": .comment
        case "match": .match
        case "message": .message
        case "club": .club
        default: .meetingRequest
        }
    }
}

private struct NotificationReadUpdate: Encodable {
    let isRead: Bool
    enum CodingKeys: String, CodingKey { case isRead = "is_read" }
}

private struct DeviceTokenUpsert: Encodable {
    let userID: UUID
    let token: String
    let platform: String
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token, platform
    }
}

private struct MyProfileRow: Decodable {
    let name: String
    let birthDate: Date
    let gender: String
    let datingPreference: String
    let relationshipIntent: String
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let interests: [String]
    let promptKeys: [String]
    let promptAnswers: [String]
    let minAge: Int
    let maxAge: Int
    let academicYears: [String]
    let departments: [String]
    let requireCommonInterest: Bool
    let campusOnly: Bool

    enum CodingKeys: String, CodingKey {
        case name, gender, university, department, bio, interests, departments
        case birthDate = "birth_date"
        case datingPreference = "dating_preference"
        case relationshipIntent = "relationship_intent"
        case academicYear = "academic_year"
        case promptKeys = "prompt_keys"
        case promptAnswers = "prompt_answers"
        case minAge = "min_age"
        case maxAge = "max_age"
        case academicYears = "academic_years"
        case requireCommonInterest = "require_common_interest"
        case campusOnly = "campus_only"
    }
}

private struct ProfileMediaRow: Decodable {
    let avatarPath: String?
    enum CodingKeys: String, CodingKey { case avatarPath = "avatar_path" }
}

private struct ProfilePhotoRow: Decodable {
    let storagePath: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case storagePath = "storage_path"
        case position
    }
}

private struct ProfilePhotoInsert: Encodable {
    let profileID: UUID
    let storagePath: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case storagePath = "storage_path"
        case position
    }
}

private struct AvatarPathUpdate: Encodable {
    let path: String?
    enum CodingKeys: String, CodingKey { case path = "avatar_path" }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let path { try container.encode(path, forKey: .path) }
        else { try container.encodeNil(forKey: .path) }
    }
}

private struct BlockParams: Encodable {
    let target: UUID
}

private struct ReportInsert: Encodable {
    let reporterID: UUID
    let reportedID: UUID
    let reason: String
    let details: String?
    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case reportedID = "reported_id"
        case reason, details
    }
}

private struct MatchRow: Decodable {
    let id: UUID
    let userA: UUID
    let userB: UUID
    let createdAt: Date
    let userAProfile: SupabaseProfileRow
    let userBProfile: SupabaseProfileRow

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "user_a"
        case userB = "user_b"
        case createdAt = "created_at"
        case userAProfile = "user_a_profile"
        case userBProfile = "user_b_profile"
    }

    func peer(for userID: UUID) -> SupabaseProfileRow {
        userA == userID ? userBProfile : userAProfile
    }
}

private struct MessageRow: Decodable {
    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let body: String
    let replyToID: UUID?
    let reaction: String?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body, reaction
        case matchID = "match_id"
        case senderID = "sender_id"
        case replyToID = "reply_to_id"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    func message(currentUserID: UUID, allRows: [MessageRow], peerName: String) -> Message {
        let reply = replyToID.flatMap { replyID in
            allRows.first(where: { $0.id == replyID }).map {
                MessageReply(messageID: $0.id, authorName: $0.senderID == currentUserID ? "Sen" : peerName, body: $0.body)
            }
        }
        return Message(id: id, body: body, isMine: senderID == currentUserID, sentAt: createdAt, reaction: reaction, replyTo: reply)
    }
}

private struct MessageInsert: Encodable {
    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let body: String
    let replyToID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, body
        case matchID = "match_id"
        case senderID = "sender_id"
        case replyToID = "reply_to_id"
    }
}

private struct MessageReadUpdate: Encodable {
    let readAt: Date
    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
}

private struct ProfilePromptPayload: Encodable {
    let promptKey: String
    let answer: String

    enum CodingKeys: String, CodingKey {
        case promptKey = "prompt_key"
        case answer
    }
}

private struct SaveProfileParams: Encodable {
    let profileName: String
    let profileBirthDate: String
    let profileGender: String
    let profileDatingPreference: String
    let profileRelationshipIntent: String
    let profileUniversity: String
    let profileDepartment: String
    let profileAcademicYear: String
    let profileBio: String
    let profileInterests: [String]
    let profilePrompts: [ProfilePromptPayload]

    enum CodingKeys: String, CodingKey {
        case profileName = "profile_name"
        case profileBirthDate = "profile_birth_date"
        case profileGender = "profile_gender"
        case profileDatingPreference = "profile_dating_preference"
        case profileRelationshipIntent = "profile_relationship_intent"
        case profileUniversity = "profile_university"
        case profileDepartment = "profile_department"
        case profileAcademicYear = "profile_academic_year"
        case profileBio = "profile_bio"
        case profileInterests = "profile_interests"
        case profilePrompts = "profile_prompts"
    }
}

private struct MessageReactionParams: Encodable {
    let messageID: UUID
    let reaction: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_uuid"
        case reaction
    }
}

private struct DiscoveryPreferencesUpsert: Encodable {
    let userID: UUID
    let minAge: Int
    let maxAge: Int
    let academicYears: [String]
    let departments: [String]
    let requireCommonInterest: Bool
    let campusOnly: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case minAge = "min_age"
        case maxAge = "max_age"
        case academicYears = "academic_years"
        case departments
        case requireCommonInterest = "require_common_interest"
        case campusOnly = "campus_only"
    }
}

private struct DiscoveryPageParams: Encodable {
    let pageLimit: Int
    let pageOffset: Int
    enum CodingKeys: String, CodingKey {
        case pageLimit = "page_limit"
        case pageOffset = "page_offset"
    }
}

private struct ReactionParams: Encodable {
    let subject: UUID
    let reaction: String
}

private struct ReactionResultRow: Decodable {
    let matched: Bool
    let matchID: UUID?
    enum CodingKeys: String, CodingKey {
        case matched
        case matchID = "match_id"
    }
}

private struct DiscoveryCandidateRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let galleryPaths: [String]
    let isVerified: Bool
    let relationshipIntent: RelationshipIntent
    let interests: [String]
    let promptKeys: [String]
    let promptAnswers: [String]
    let compatibility: Int
    let compatibilityReasons: [String]
    let activeLabel: String

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests, compatibility
        case birthDate = "birth_date"
        case avatarPath = "avatar_path"
        case galleryPaths = "gallery_paths"
        case academicYear = "academic_year"
        case isVerified = "is_verified"
        case relationshipIntent = "relationship_intent"
        case promptKeys = "prompt_keys"
        case promptAnswers = "prompt_answers"
        case compatibilityReasons = "compatibility_reasons"
        case activeLabel = "active_label"
    }

    func studentProfile(avatarURL: URL?, galleryURLs: [URL]) -> StudentProfile {
        let age = max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
        return StudentProfile(
            id: id, name: name, age: age, university: university, department: department,
            year: academicYear, bio: bio, interests: interests, imageURL: avatarURL,
            galleryImageURLs: galleryURLs,
            compatibility: compatibility, isVerified: isVerified,
            compatibilityReasons: compatibilityReasons,
            prompts: zip(promptKeys, promptAnswers).map { ProfilePrompt(question: $0.0, answer: $0.1) },
            relationshipIntent: relationshipIntent, activeLabel: activeLabel
        )
    }
}

private struct PromptInsert: Encodable {
    let profileID: UUID
    let promptKey: String
    let answer: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case promptKey = "prompt_key"
        case answer, position
    }
}

private struct InterestInsert: Encodable {
    let profileID: UUID
    let interest: String

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case interest
    }
}

private struct PostInsert: Encodable {
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?

    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case caption
        case placeName = "place_name"
        case mediaPath = "media_path"
    }
}

private struct CommentInsert: Encodable {
    let postID: UUID
    let authorID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case authorID = "author_id"
        case body
    }
}

private struct SupabaseProfileRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool

    func studentProfile(avatarURL: URL?) -> StudentProfile {
        let age = max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
        return StudentProfile(
            id: id, name: name, age: age, university: university, department: department,
            year: academicYear, bio: bio, interests: [], imageURL: avatarURL,
            compatibility: 0, isVerified: isVerified, activeLabel: "Eşleşme"
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio
        case birthDate = "birth_date"
        case avatarPath = "avatar_path"
        case academicYear = "academic_year"
        case isVerified = "is_verified"
    }
}

private struct CommentAuthorRow: Decodable {
    let name: String
}

private struct CommentRow: Decodable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let body: String
    let createdAt: Date
    let author: CommentAuthorRow

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }

    var backendComment: BackendComment {
        BackendComment(
            id: id,
            postID: postID,
            authorID: authorID,
            authorName: author.name,
            body: body,
            createdAt: createdAt
        )
    }
}

private struct PostRow: Decodable {
    let id: UUID
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?
    let createdAt: Date
    let author: SupabaseProfileRow
    let comments: [CommentRow]

    enum CodingKeys: String, CodingKey {
        case id, caption, author, comments
        case authorID = "author_id"
        case placeName = "place_name"
        case mediaPath = "media_path"
        case createdAt = "created_at"
    }

    func backendPost(imageData: Data?, authorAvatarURL: URL?, likeCount: Int, liked: Bool, saved: Bool) -> BackendPost {
        BackendPost(
            id: id,
            authorID: authorID,
            authorName: author.name,
            authorBirthDate: author.birthDate,
            authorUniversity: author.university,
            authorDepartment: author.department,
            authorYear: author.academicYear,
            authorBio: author.bio,
            authorVerified: author.isVerified,
            authorAvatarURL: authorAvatarURL,
            caption: caption,
            placeName: placeName,
            imageData: imageData,
            createdAt: createdAt,
            comments: comments.sorted { $0.createdAt < $1.createdAt }.map(\.backendComment),
            likeCount: likeCount,
            liked: liked,
            saved: saved
        )
    }
}

private struct SavedPostRow: Decodable {
    let postID: UUID
    enum CodingKeys: String, CodingKey { case postID = "post_id" }
}

private struct SavedPostInsert: Encodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}

private struct PostLikeRow: Decodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}

private struct PostLikeInsert: Encodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}
