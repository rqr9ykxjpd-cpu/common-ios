import Foundation
import Supabase

private let postListSelect = "id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path))"

extension SupabaseProductService {
    func fetchFeed() async throws -> [BackendPost] {
        let rows: [PostRow] = try await client
            .from("posts")
            .select(postListSelect)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        return await hydratePosts(rows, savedIDs: nil)
    }

    func countMyPosts() async throws -> Int {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let response = try await client
            .from("posts")
            .select("id", head: true, count: .exact)
            .eq("author_id", value: userID)
            .execute()
        return response.count ?? 0
    }

    /// Kaydedilen gönderiler doğrudan `saved_posts` üzerinden çekiliyor.
    ///
    /// Önceden bu liste yüklü akıştan süzülüyordu (`posts.filter(\.saved)`) ama akış
    /// yalnızca son 100 gönderiyi getiriyor. Eski bir gönderiyi kaydeden kişi onu yer
    /// imlerinde bulamıyordu: kayıt sunucuda duruyor, uygulama göstermiyordu.
    func fetchSavedPosts() async throws -> [BackendPost] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let saved: [SavedPostRow] = try await client
            .from("saved_posts")
            .select("post_id")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
        let ids = saved.map(\.postID)
        guard !ids.isEmpty else { return [] }

        let rows: [PostRow] = try await client
            .from("posts")
            .select(postListSelect)
            .`in`("id", values: ids)
            .order("created_at", ascending: false)
            .execute()
            .value
        return await hydratePosts(rows, savedIDs: Set(ids))
    }

    /// Gönderi görsellerini tek tek indirmiyoruz: profil ızgarasıyla aynı
    /// toplu imzalı URL. Aksi halde akış, fotoğraf sayısı kadar sıralı
    /// `download` bekliyordu.
    private func hydratePosts(_ rows: [PostRow], savedIDs: Set<UUID>?) async -> [BackendPost] {
        guard !rows.isEmpty else { return [] }
        let ids = rows.map(\.id)
        let userID = currentUserID
        async let avatarURLs = signedURLs(
            bucket: "profile-photos",
            paths: rows.compactMap { $0.author.avatarPath }
                + rows.flatMap { $0.comments }.compactMap { $0.author.avatarPath }
        )
        async let mediaURLs = signedURLs(
            bucket: "post-media",
            paths: rows.compactMap(\.mediaPath)
        )
        async let likeRows: [PostLikeRow] = (try? await client
            .from("post_likes")
            .select("post_id,user_id")
            .`in`("post_id", values: ids)
            .execute()
            .value) ?? []
        async let authorBadges = badges(for: rows.map(\.authorID))
        let resolvedSaved: Set<UUID>
        if let savedIDs {
            resolvedSaved = savedIDs
        } else {
            resolvedSaved = Set(((try? await client
                .from("saved_posts")
                .select("post_id")
                .`in`("post_id", values: ids)
                .execute()
                .value) as [SavedPostRow]? ?? []).map(\.postID))
        }
        let avatars = await avatarURLs
        let media = await mediaURLs
        let likes = await likeRows
        let badgeMap = await authorBadges
        return rows.map { row in
            let postLikes = likes.filter { $0.postID == row.id }
            return row.backendPost(
                imageData: nil,
                authorAvatarURL: row.author.avatarPath.flatMap { avatars[$0] },
                likeCount: postLikes.count,
                liked: userID.map { id in postLikes.contains { $0.userID == id } } ?? false,
                saved: resolvedSaved.contains(row.id),
                badge: badgeMap[row.authorID] ?? .none,
                commentAvatarURLs: avatars,
                imageURL: row.mediaPath.flatMap { media[$0] }
            )
        }
    }

    /// Rozetler ayrı çekiliyor.
    ///
    /// Doğrudan `select(...,badge)` yazmak, kolon henüz sunucuda yoksa (migration
    /// çalıştırılmadıysa) tüm sorguyu hataya düşürüyordu — akış ve sohbetler komple
    /// kırılıyordu. Ayrı ve `try?` ile: kolon varsa rozet gelir, yoksa uygulama
    /// hiçbir şey kaybetmeden çalışmaya devam eder.
    func createPost(caption: String, placeName: String?, imageData: Data?) async throws -> BackendPost {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if try await countMyPosts() >= CampusLimits.maxPostsPerUser {
            let plan = try await fetchMyPlan()
            if plan.maxPosts != nil { throw BackendServiceError.postLimit }
        }
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
        let row: PostRow
        do {
            row = try await client
                .from("posts")
                .insert(payload)
                .select(postListSelect)
                .single()
                .execute()
                .value
        } catch {
            if let mediaPath {
                _ = try? await client.storage.from("post-media").remove(paths: [mediaPath])
            }
            if String(describing: error).localizedCaseInsensitiveContains("quota_post")
                || String(describing: error).localizedCaseInsensitiveContains("post_limit") {
                throw BackendServiceError.postLimit
            }
            throw error
        }
        var authorAvatarURL: URL?
        if let path = row.author.avatarPath {
            authorAvatarURL = publicProfilePhotoURL(path)
        }
        // Az önce çekilen fotoğraf zaten elde; imzalı URL yenilemede yedek.
        var imageURL: URL?
        if let mediaPath {
            imageURL = (await signedURLs(bucket: "post-media", paths: [mediaPath]))[mediaPath]
        }
        // Rozet burada hiç geçirilmiyordu → yeni atılan gönderide kurucu/mod rozeti
        // kayboluyor, akış yenilenince (fetchFeed badges çeker) geri geliyordu.
        let badge = await badges(for: [userID])[userID] ?? .none
        return row.backendPost(
            imageData: imageData,
            authorAvatarURL: authorAvatarURL,
            likeCount: 0,
            liked: false,
            saved: false,
            badge: badge,
            imageURL: imageURL
        )
    }

    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let payload = CommentInsert(postID: postID, authorID: userID, body: body)
        let row: CommentRow = try await client
            .from("comments")
            .insert(payload)
            .select("id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path)")
            .single()
            .execute()
            .value
        var avatarURL: URL?
        if let path = row.author.avatarPath {
            avatarURL = publicProfilePhotoURL(path)
        }
        return row.backendComment(avatarURL: avatarURL)
    }

    /// Önce depolamadaki dosya, sonra satır.
    ///
    /// Eskiden satır silinince bir tetikleyici `storage.objects`'ten de siliyordu,
    /// ama Supabase doğrudan silmeyi engelliyor ("Direct deletion from storage tables
    /// is not allowed") ve tetikleyici hata verince silmenin tamamı geri sarılıyordu.
    /// Dosya silme artık burada, Storage API üzerinden.
    ///
    /// Dosya silinemezse satır yine de siliniyor: kullanıcı açısından önemli olan
    /// gönderinin kaybolması. Geride kalan dosyaya kimse erişemiyor, yalnızca yer
    /// kaplıyor — bunun için silmeyi engellemek yanlış olurdu.
    func deletePost(_ postID: UUID) async throws {
        await removeMedia(bucket: "post-media", table: "posts", rowID: postID)
        try await client.from("posts").delete(returning: .minimal).eq("id", value: postID).execute()
    }

    func deleteComment(_ commentID: UUID) async throws {
        try await client.from("comments").delete(returning: .minimal).eq("id", value: commentID).execute()
    }

    /// Satın almayı sunucudaki Edge Function'a iletir. Doğrulama orada:
    /// fonksiyon JWS'i Apple'ın App Store Server API'siyle kontrol edip
    /// `subscriptions` tablosunu kendisi yazıyor. İstemcinin bu tabloya yazma
    func setPostLiked(_ postID: UUID, liked: Bool) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        if liked {
            try await client.from("post_likes")
                .upsert(PostLikeInsert(postID: postID, userID: userID), returning: .minimal,
                        ignoreDuplicates: true)
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
                .upsert(SavedPostInsert(postID: postID, userID: userID), returning: .minimal,
                        ignoreDuplicates: true)
                .execute()
        } else {
            try await client.from("saved_posts")
                .delete(returning: .minimal)
                .eq("post_id", value: postID)
                .eq("user_id", value: userID)
                .execute()
        }
    }
    func fetchStories() async throws -> [CampusStory] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [StoryRow] = try await client
            .from("stories")
            .select("""
            id,author_id,media_path,caption,place_id,created_at,expires_at,media_kind,duration_ms,poster_path,\
            author:profiles!stories_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),\
            place:places!stories_place_id_fkey(id,name,area),\
            story_views(viewer_id,view_count,last_viewed_at)
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        let mediaURLs = await signedURLs(
            bucket: "story-media",
            paths: rows.map(\.mediaPath) + rows.compactMap(\.posterPath)
        )
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap { $0.author?.avatarPath })
        // Join select’te badge yok; postlarda olduğu gibi ayrı çekiyoruz.
        let authorBadges = await badges(for: rows.map(\.authorID))
        // Nested `story_views` bazen yalnızca kendi satırını döndürüyor. Kendi
        // story'lerinin izlenme sayısı için ayrı okuyoruz: sahip RLS ile hepsini görür.
        let ownStoryIDs = rows.filter { $0.authorID == userID }.map(\.id)
        let ownViews: [StoryViewListRow] = ownStoryIDs.isEmpty ? [] : ((try? await client
            .from("story_views")
            .select("story_id,viewer_id,view_count,last_viewed_at")
            .in("story_id", values: ownStoryIDs)
            .execute()
            .value) ?? [])
        var viewsByStory: [UUID: [StoryViewListRow]] = [:]
        for view in ownViews {
            viewsByStory[view.storyID, default: []].append(view)
        }
        return rows.compactMap { row in
            guard let author = row.author else { return nil }
            let profile = author.studentProfile(avatarURL: author.avatarPath.flatMap { avatarURLs[$0] })
                .withBadge(authorBadges[row.authorID] ?? author.badge ?? .none)
            let isMine = row.authorID == userID
            let viewRecords: [StoryViewRecord] = isMine
                ? (viewsByStory[row.id] ?? []).map { view in
                    StoryViewRecord(
                        viewer: .anonymousViewer(id: view.viewerID),
                        viewCount: view.viewCount,
                        lastViewedAt: view.lastViewedAt
                    )
                }
                : []
            let kind = row.kind
            let isVideo = kind == .video
            return CampusStory(
                id: row.id,
                author: profile,
                imageURL: isVideo ? row.posterPath.flatMap { mediaURLs[$0] } : mediaURLs[row.mediaPath],
                caption: row.caption,
                place: row.place.map { CampusPlace(id: $0.id, name: $0.name, area: $0.area) },
                viewed: row.storyViews?.contains { $0.viewerID == userID } ?? false,
                viewRecords: viewRecords,
                isMine: isMine,
                expiresAt: row.expiresAt,
                mediaKind: kind,
                videoURL: isVideo ? mediaURLs[row.mediaPath] : nil,
                posterURL: row.posterPath.flatMap { mediaURLs[$0] },
                duration: row.durationMs.map { TimeInterval($0) / 1000 }
            )
        }
    }

    func publishStory(_ upload: StoryUpload, caption: String, placeID: UUID?) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let folder = userID.uuidString.lowercased()
        let captionText = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let expires = Date().addingTimeInterval(CampusStory.lifetime)

        switch upload {
        case .photo(let imageData):
            let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
            try await client.storage.from("story-media")
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            do {
                try await client.from("stories")
                    .insert(
                        StoryInsert(
                            authorID: userID, mediaPath: path, caption: captionText, placeID: placeID,
                            expiresAt: expires, mediaKind: "image", durationMs: nil, posterPath: nil
                        ),
                        returning: .minimal
                    )
                    .execute()
            } catch {
                _ = try? await client.storage.from("story-media").remove(paths: [path])
                throw error
            }

        case .video(let fileURL, let posterJPEG, let duration):
            let mediaPath = "\(folder)/\(UUID().uuidString.lowercased()).mp4"
            let posterPath = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
            let videoData = try Data(contentsOf: fileURL)
            try await client.storage.from("story-media")
                .upload(mediaPath, data: videoData, options: FileOptions(contentType: "video/mp4"))
            do {
                try await client.storage.from("story-media")
                    .upload(posterPath, data: posterJPEG, options: FileOptions(contentType: "image/jpeg"))
            } catch {
                _ = try? await client.storage.from("story-media").remove(paths: [mediaPath])
                throw error
            }
            let durationMs = min(15_000, max(1, Int((duration * 1000).rounded())))
            do {
                try await client.from("stories")
                    .insert(
                        StoryInsert(
                            authorID: userID, mediaPath: mediaPath, caption: captionText, placeID: placeID,
                            expiresAt: expires, mediaKind: "video", durationMs: durationMs, posterPath: posterPath
                        ),
                        returning: .minimal
                    )
                    .execute()
            } catch {
                _ = try? await client.storage.from("story-media").remove(paths: [mediaPath, posterPath])
                throw error
            }
        }
    }

    func deleteStory(_ storyID: UUID) async throws {
        await removeStoryFiles(storyID)
        try await client.from("stories").delete(returning: .minimal).eq("id", value: storyID).execute()
    }

    func markStoryViewed(_ storyID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        // `view_count` sütunu baştan vardı ama kimse artırmıyordu: upsert yalnızca
        // gönderdiği sütunları güncellediği için sayı sonsuza kadar 1'de kalıyordu.
        // PostgREST üzerinden `view_count = view_count + 1` yazılamadığından mevcut
        // değeri okuyup üstüne yazıyoruz. RLS herkese kendi satırını okuma ve
        // güncelleme izni veriyor, bu yüzden ayrı bir sunucu fonksiyonu gerekmiyor.
        let mevcut: [StoryViewCountRow] = try await client.from("story_views")
            .select("view_count")
            .eq("story_id", value: storyID)
            .eq("viewer_id", value: userID)
            .limit(1)
            .execute()
            .value
        try await client.from("story_views")
            .upsert(
                StoryViewUpsert(storyID: storyID, viewerID: userID,
                                viewCount: (mevcut.first?.viewCount ?? 0) + 1,
                                lastViewedAt: Date()),
                onConflict: "story_id,viewer_id",
                returning: .minimal
            )
            .execute()
    }
}
