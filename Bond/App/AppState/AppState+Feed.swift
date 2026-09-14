import SwiftUI

// MARK: - AppState+Feed
extension AppState {
    /// ▲ / ▼: aynı yöne ikinci dokunuş oyu geri alır, ters yön oyu çevirir.
    /// Önce ekranda, sonra sunucuda; sunucu reddederse eski hâle döner.
    func vote(postID: UUID, up: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let eski = posts[index].myVote
        let yeni = (up ? 1 : -1) == eski ? 0 : (up ? 1 : -1)
        apply(vote: yeni, postID: postID)
        Haptics.impact(.light)
        Task {
            do {
                try await service.setPostVote(postID, value: yeni)
            } catch {
                apply(vote: eski, postID: postID)
                showError(error, fallback: L10n.Feed.likeFailed)
            }
        }
    }

    private func apply(vote: Int, postID: UUID) {
        guard let i = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[i].likeCount += vote - posts[i].myVote
        posts[i].liked = vote == 1
        posts[i].downvoted = vote == -1
    }

    /// Eski çağrılar için: ▲ ile aynı.
    func toggleLike(postID: UUID) { vote(postID: postID, up: true) }

    /// Kart ekrana geldi; bir sonraki yüklemede sıralama bunu hesaba katar.
    func markPostSeen(_ postID: UUID) {
        FeedSeenTracker.markSeen(postID)
    }

    // MARK: Kurucu araçları

    /// Gönderiye `extra` oy ekler (eksi geri alır). Sunucu kurucu rozetini kontrol eder.
    func boostPost(_ postID: UUID, extra: Int) {
        guard extra != 0, let i = posts.firstIndex(where: { $0.id == postID }) else { return }
        let eskiBoost = posts[i].boost
        let yeniBoost = max(0, eskiBoost + extra)
        posts[i].likeCount += yeniBoost - eskiBoost
        posts[i].boost = yeniBoost
        feedRankVersion += 1
        Haptics.success()
        Task {
            do {
                let sunucu = try await service.boostPost(postID, extra: extra)
                guard let j = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[j].likeCount += sunucu - posts[j].boost
                posts[j].boost = sunucu
            } catch {
                guard let j = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[j].likeCount += eskiBoost - posts[j].boost
                posts[j].boost = eskiBoost
                feedRankVersion += 1
                showError(error, fallback: L10n.Board.founderActionFailed)
            }
        }
    }

    /// Cevaba `extra` oy ekler (eksi geri alır); boostPost ile aynı akış.
    func boostComment(postID: UUID, commentID: UUID, extra: Int) {
        guard extra != 0,
              let pi = posts.firstIndex(where: { $0.id == postID }),
              let ci = posts[pi].comments.firstIndex(where: { $0.id == commentID }) else { return }
        let eskiBoost = posts[pi].comments[ci].boost
        let yeniBoost = max(0, eskiBoost + extra)
        posts[pi].comments[ci].voteCount += yeniBoost - eskiBoost
        posts[pi].comments[ci].boost = yeniBoost
        Haptics.success()
        Task {
            do {
                let sunucu = try await service.boostComment(commentID, extra: extra)
                guard let pj = posts.firstIndex(where: { $0.id == postID }),
                      let cj = posts[pj].comments.firstIndex(where: { $0.id == commentID }) else { return }
                posts[pj].comments[cj].voteCount += sunucu - posts[pj].comments[cj].boost
                posts[pj].comments[cj].boost = sunucu
            } catch {
                guard let pj = posts.firstIndex(where: { $0.id == postID }),
                      let cj = posts[pj].comments.firstIndex(where: { $0.id == commentID }) else { return }
                posts[pj].comments[cj].voteCount += eskiBoost - posts[pj].comments[cj].boost
                posts[pj].comments[cj].boost = eskiBoost
                showError(error, fallback: L10n.Board.founderActionFailed)
            }
        }
    }

    func fetchPostVoters(_ postID: UUID) async throws -> [PostVoter] {
        try await service.fetchPostVoters(postID)
    }

    func fetchCommentVoters(_ commentID: UUID) async throws -> [PostVoter] {
        try await service.fetchCommentVoters(commentID)
    }

    /// Gönderiyi `slot`. sıraya sabitler (1 = en üst); nil kaldırır.
    func setPostPin(_ postID: UUID, slot: Int?) {
        guard let i = posts.firstIndex(where: { $0.id == postID }) else { return }
        let eskiAt = posts[i].pinnedAt, eskiSlot = posts[i].pinnedSlot
        posts[i].pinnedAt = slot == nil ? nil : Date()
        posts[i].pinnedSlot = slot.map { min(max($0, 1), 20) }
        feedRankVersion += 1
        Haptics.success()
        Task {
            do {
                try await service.setPostPin(postID, slot: posts[i].pinnedSlot)
            } catch {
                guard let j = posts.firstIndex(where: { $0.id == postID }) else { return }
                posts[j].pinnedAt = eskiAt
                posts[j].pinnedSlot = eskiSlot
                feedRankVersion += 1
                showError(error, fallback: L10n.Board.founderActionFailed)
            }
        }
    }

    func loadFeed() async {
        feedLoadGeneration += 1
        let generation = feedLoadGeneration
        let userID = currentUserID
        isLoadingFeed = true
        defer { if generation == feedLoadGeneration { isLoadingFeed = false } }
        // Gönderinin yeri, sunucudan gelen yer *adı* `places` listesiyle eşleştirilerek
        // çözülüyor ve dönüşüm anında sabitleniyor. Akış ekranı açılışta `loadFeed`'i
        // kendi başına çağırdığı için bu, yerleri yükleyen `restoreBackendSession` ile
        // yarışıyordu: akış önce biterse bütün gönderiler konum etiketini kaybediyor ve
        // kullanıcı akışı elle yenileyene kadar geri gelmiyordu.
        if places.isEmpty { await loadPlaces() }
        guard generation == feedLoadGeneration, userID == currentUserID, !Task.isCancelled else { return }
        do {
            let result = try await service.fetchFeed()
            guard generation == feedLoadGeneration, userID == currentUserID, !Task.isCancelled else { return }
            justPublishedPostIDs.removeAll()
            seenCounts = FeedSeenTracker.snapshot()
            feedRankVersion += 1
            posts = result.map { backend in
                let social = socialPost(from: backend)
                if social.isMine, social.author.badge == .none, myBadge != .none {
                    return socialPost(from: backend, badgeOverride: myBadge)
                }
                return social
            }
            feedError = nil
        } catch {
            guard generation == feedLoadGeneration, userID == currentUserID, !isCancellation(error) else { return }
            feedError = UserFacingError.message(error, fallback: L10n.Feed.loadFailed)
        }
    }

    @discardableResult
    func publishPost(imageData: Data?, caption: String, place: CampusPlace?, kind: PostKind = .moment, announces: Bool = true) async -> Bool {
        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard imageData != nil || !cleanCaption.isEmpty else { return false }
        do {
            let post = try await service.createPost(caption: cleanCaption, placeName: place?.name, imageData: imageData, kind: kind)
            var social = socialPost(from: post)
            // Sunucu rozeti kaçırsa bile kendi gönderinde yerel rozet kalsın.
            if social.isMine, social.author.badge == .none, myBadge != .none {
                social = socialPost(from: post, badgeOverride: myBadge)
            }
            posts.insert(social, at: 0)
            justPublishedPostIDs.insert(social.id)
            // Başka rozete bakarken paylaşan kişi kendi gönderisini göremiyordu;
            // filtre uymuyorsa akış "Tümü"ye döner, gönderi en üstte.
            if let filter = selectedKindFilter, filter != kind {
                withAnimation(BondTheme.Motion.snappy) { selectedKindFilter = nil }
            }
            Haptics.success()
            if announces { show(L10n.Composer.postShared) }
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

    /// Cevaba ▲ / ▼. Kendi cevabına oy yok; kurucu istisna (sunucu da aynı kuralı uygular).
    func voteComment(postID: UUID, commentID: UUID, up: Bool) {
        guard let pi = posts.firstIndex(where: { $0.id == postID }),
              let ci = posts[pi].comments.firstIndex(where: { $0.id == commentID }),
              !posts[pi].comments[ci].isMine || isFounder else { return }
        let eski = posts[pi].comments[ci].myVote
        let yeni = (up ? 1 : -1) == eski ? 0 : (up ? 1 : -1)
        apply(vote: yeni, postID: postID, commentID: commentID)
        Haptics.impact(.light)
        Task {
            do {
                try await service.setCommentVote(commentID, value: yeni)
            } catch {
                apply(vote: eski, postID: postID, commentID: commentID)
                showError(error, fallback: L10n.Feed.likeFailed)
            }
        }
    }

    private func apply(vote: Int, postID: UUID, commentID: UUID) {
        guard let pi = posts.firstIndex(where: { $0.id == postID }),
              let ci = posts[pi].comments.firstIndex(where: { $0.id == commentID }) else { return }
        posts[pi].comments[ci].voteCount += vote - posts[pi].comments[ci].myVote
        posts[pi].comments[ci].voted = vote == 1
        posts[pi].comments[ci].downvoted = vote == -1
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
            kind: post.kind,
            liked: post.liked,
            downvoted: post.downvoted,
            saved: post.saved,
            isMine: post.authorID == currentUserID,
            likeCount: post.likeCount,
            comments: post.comments.map(socialComment(from:)),
            createdAt: post.createdAt,
            boost: post.boost,
            pinnedAt: post.pinnedAt,
            pinnedSlot: post.pinnedSlot
        )
    }

    func socialComment(from comment: BackendComment) -> SocialComment {
        SocialComment(
            id: comment.id,
            author: comment.authorName,
            authorAvatarURL: comment.authorAvatarURL,
            body: comment.body,
            isMine: comment.authorID == currentUserID,
            createdAt: comment.createdAt,
            voteCount: comment.voteCount,
            voted: comment.voted,
            downvoted: comment.downvoted,
            boost: comment.boost
        )
    }
}
