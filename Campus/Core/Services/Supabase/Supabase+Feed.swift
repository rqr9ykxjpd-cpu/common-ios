import Foundation
import Supabase

extension SupabaseProductService {
    func fetchFeed() async throws -> [BackendPost] {
        let rows: [PostRow] = try await client
            .from("posts")
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path))")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        // Yorum yazarlarının fotoğrafları da aynı toplu imzalamaya giriyor;
        // satır başına ayrı istek atmamak için.
        let avatarURLs = await signedURLs(
            bucket: "profile-photos",
            paths: rows.compactMap { $0.author.avatarPath }
                + rows.flatMap { $0.comments }.compactMap { $0.author.avatarPath }
        )
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
        let authorBadges = await badges(for: rows.map(\.authorID))
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
                saved: savedIDs.contains(row.id),
                badge: authorBadges[row.authorID] ?? .none,
                commentAvatarURLs: avatarURLs
            ))
        }
        return posts
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
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path))")
            .`in`("id", values: ids)
            .order("created_at", ascending: false)
            .execute()
            .value
        // Yorum yazarlarının fotoğrafları da aynı toplu imzalamaya giriyor;
        // satır başına ayrı istek atmamak için.
        let avatarURLs = await signedURLs(
            bucket: "profile-photos",
            paths: rows.compactMap { $0.author.avatarPath }
                + rows.flatMap { $0.comments }.compactMap { $0.author.avatarPath }
        )
        let likeRows: [PostLikeRow] = rows.isEmpty ? [] : ((try? await client
            .from("post_likes")
            .select("post_id,user_id")
            .`in`("post_id", values: rows.map(\.id))
            .execute()
            .value) ?? [])

        var posts: [BackendPost] = []
        for row in rows {
            var imageData: Data?
            if let mediaPath = row.mediaPath {
                imageData = try? await client.storage.from("post-media").download(path: mediaPath)
            }
            let postLikes = likeRows.filter { $0.postID == row.id }
            posts.append(row.backendPost(
                imageData: imageData,
                authorAvatarURL: row.author.avatarPath.flatMap { avatarURLs[$0] },
                likeCount: postLikes.count,
                liked: postLikes.contains { $0.userID == userID },
                saved: true
            ))
        }
        return posts
    }

    /// Rozetler ayrı çekiliyor.
    ///
    /// Doğrudan `select(...,badge)` yazmak, kolon henüz sunucuda yoksa (migration
    /// çalıştırılmadıysa) tüm sorguyu hataya düşürüyordu — akış ve sohbetler komple
    /// kırılıyordu. Ayrı ve `try?` ile: kolon varsa rozet gelir, yoksa uygulama
    /// hiçbir şey kaybetmeden çalışmaya devam eder.
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
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path))")
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
            .select("id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path)")
            .single()
            .execute()
            .value
        var avatarURL: URL?
        if let path = row.author.avatarPath {
            avatarURL = try? await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3_600)
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
                                    placeID: placeID,
                                    expiresAt: Date().addingTimeInterval(CampusStory.lifetime)),
                        returning: .minimal)
                .execute()
        } catch {
            // Satır eklenemezse yüklenen dosya sahipsiz kalmasın.
            _ = try? await client.storage.from("story-media").remove(paths: [path])
            throw error
        }
    }

    func deleteStory(_ storyID: UUID) async throws {
        await removeMedia(bucket: "story-media", table: "stories", rowID: storyID)
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
                returning: .minimal
            )
            .execute()
    }
}
