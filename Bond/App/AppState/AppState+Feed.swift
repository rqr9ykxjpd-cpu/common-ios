import SwiftUI

// MARK: - AppState+Feed
extension AppState {
    func toggleLike(postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let newLiked = !posts[index].liked
        posts[index].liked = newLiked
        posts[index].likeCount += newLiked ? 1 : -1
        Haptics.impact(.light)
        Task {
            do {
                try await service.setPostLiked(postID, liked: newLiked)
            } catch {
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].liked = !newLiked
                posts[refreshedIndex].likeCount += newLiked ? -1 : 1
                showError(error, fallback: L10n.Feed.likeFailed)
            }
        }
    }

    func loadFeed() async {
        // Gönderinin yeri, sunucudan gelen yer *adı* `places` listesiyle eşleştirilerek
        // çözülüyor ve dönüşüm anında sabitleniyor. Akış ekranı açılışta `loadFeed`'i
        // kendi başına çağırdığı için bu, yerleri yükleyen `restoreBackendSession` ile
        // yarışıyordu: akış önce biterse bütün gönderiler konum etiketini kaybediyor ve
        // kullanıcı akışı elle yenileyene kadar geri gelmiyordu.
        if places.isEmpty { await loadPlaces() }
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        do {
            posts = try await service.fetchFeed().map { backend in
                let social = socialPost(from: backend)
                if social.isMine, social.author.badge == .none, myBadge != .none {
                    return socialPost(from: backend, badgeOverride: myBadge)
                }
                return social
            }
        } catch {
            showError(error, fallback: L10n.Feed.loadFailed)
        }
    }

    @discardableResult
    func publishPost(imageData: Data?, caption: String, place: CampusPlace?) async -> Bool {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageData != nil || !cleanCaption.isEmpty else { return false }
        do {
            let post = try await service.createPost(caption: cleanCaption, placeName: place?.name, imageData: imageData)
            var social = socialPost(from: post)
            // Sunucu rozeti kaçırsa bile kendi gönderinde yerel rozet kalsın.
            if social.isMine, social.author.badge == .none, myBadge != .none {
                social = socialPost(from: post, badgeOverride: myBadge)
            }
            posts.insert(social, at: 0)
            Haptics.success()
            show(L10n.Composer.postShared)
            return true
        } catch {
            showError(error, fallback: L10n.Feed.postFailed)
            return false
        }
    }

    func countMyPosts() async -> Int {
        do {
            return try await service.countMyPosts()
        } catch {
            return posts.filter(\.isMine).count
        }
    }
    /// Gönderi hem akışta hem kaydedilenler listesinde bulunabilir; ikisi de güncelleniyor.
    ///
    /// Önceden yalnızca akışa bakılıyordu (`guard let index = posts.firstIndex...`).
    /// Kaydedilenler sayfasında akışta olmayan eski bir gönderinin yer imini kaldırmaya
    /// çalışınca guard'a takılıyor ve düğme hiçbir şey yapmıyordu.
    func toggleSaved(postID: UUID) {
        let current = posts.first(where: { $0.id == postID })?.saved
            ?? savedPosts.contains(where: { $0.id == postID })
        let newSaved = !current

        applySaved(newSaved, to: postID)
        Haptics.impact(.light)
        Task {
            do {
                try await service.setPostSaved(postID, saved: newSaved)
            } catch {
                applySaved(!newSaved, to: postID)
                showError(error, fallback: L10n.Feed.saveFailed)
            }
        }
    }

    func applySaved(_ saved: Bool, to postID: UUID) {
        if let index = posts.firstIndex(where: { $0.id == postID }) {
            posts[index].saved = saved
        }
        if saved {
            if !savedPosts.contains(where: { $0.id == postID }),
               var post = posts.first(where: { $0.id == postID }) {
                post.saved = true
                savedPosts.insert(post, at: 0)
            }
        } else {
            savedPosts.removeAll { $0.id == postID }
        }
    }

    /// Kaydedilen gönderiler. Yer imi butonu yalnızca yerel durumu değiştiriyordu ve
    /// kaydedilenleri görecek bir ekran da yoktu; buton hiçbir işe yaramıyordu.
    /// Kaydedilen gönderiler sunucudan ayrıca çekiliyor; akıştan süzmek yetmiyordu
    /// çünkü akış yalnızca son 100 gönderiyi getiriyor.
    func loadSavedPosts() async {
        do {
            savedPosts = try await service.fetchSavedPosts().map { socialPost(from: $0) }
        } catch {
            showError(error, fallback: L10n.Feed.savedLoadFailed)
        }
    }

    func deletePost(_ postID: UUID) {
        guard posts.contains(where: { $0.id == postID && $0.isMine }) else { return }
        Task {
            do {
                try await service.deletePost(postID)
                posts.removeAll { $0.id == postID }
                show(L10n.Feed.postDeleted)
                Haptics.success()
            } catch {
                showError(error, fallback: L10n.Feed.deletePostFailed)
            }
        }
    }
    func addComment(_ body: String, to postID: UUID) {
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBody.isEmpty, posts.contains(where: { $0.id == postID }) else { return }
        Task {
            do {
                let comment = try await service.addComment(cleanBody, to: postID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.append(socialComment(from: comment))
                Haptics.impact(.light)
            } catch {
                showError(error, fallback: L10n.Feed.commentFailed)
            }
        }
    }

    func deleteComment(_ commentID: UUID, from postID: UUID) {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              posts[postIndex].comments.contains(where: { $0.id == commentID && $0.isMine }) else { return }
        Task {
            do {
                try await service.deleteComment(commentID)
                guard let refreshedIndex = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[refreshedIndex].comments.removeAll { $0.id == commentID }
                show(L10n.Feed.commentDeleted)
                Haptics.success()
            } catch {
                showError(error, fallback: L10n.Feed.deleteCommentFailed)
            }
        }
    }
    func socialPost(from post: BackendPost, badgeOverride: ProfileBadge? = nil) -> SocialPost {
        let age = max(18, Calendar.current.dateComponents([.year], from: post.authorBirthDate, to: .now).year ?? 18)
        let author = StudentProfile(
            id: post.authorID,
            name: post.authorName,
            age: age,
            university: post.authorUniversity,
            department: post.authorDepartment,
            year: post.authorYear,
            bio: post.authorBio,
            interests: [],
            imageURL: post.authorAvatarURL,
            compatibility: 0,
            isVerified: post.authorVerified,
            badge: badgeOverride ?? post.authorBadge
        )
        return SocialPost(
            id: post.id,
            author: author,
            caption: post.caption,
            imageURL: post.imageURL,
            localImageData: post.imageData,
            place: post.placeName.flatMap { name in places.first { $0.name == name } },
            liked: post.liked,
            saved: post.saved,
            isMine: post.authorID == currentUserID,
            likeCount: post.likeCount,
            comments: post.comments.map(socialComment(from:)),
            createdAt: post.createdAt
        )
    }

    func socialComment(from comment: BackendComment) -> SocialComment {
        SocialComment(
            id: comment.id,
            author: comment.authorName,
            authorAvatarURL: comment.authorAvatarURL,
            body: comment.body,
            isMine: comment.authorID == currentUserID,
            createdAt: comment.createdAt
        )
    }
}
