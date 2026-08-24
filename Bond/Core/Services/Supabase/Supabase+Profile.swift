import Foundation
import Supabase

extension SupabaseProductService {
    func saveProfile(_ draft: ProfileDraft) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        guard let gender = draft.gender,
              let datingPreference = draft.datingPreference else {
            throw BackendServiceError.incompleteProfile
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
            profileInterests: draft.interests.sorted()
        )
        try await client.rpc("save_my_profile", params: params).execute()
    }
    func submitPurchase(jws: String, productID: String) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.functions.invoke(
            "verify-purchase",
            options: FunctionInvokeOptions(body: PurchasePayload(jws: jws, productID: productID))
        )
    }

    func fetchMyPlan() async throws -> SubscriptionTier {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let plan: String = try await client.rpc("my_plan").execute().value
        return SubscriptionTier(serverValue: plan)
    }

    func fetchMyProfile() async throws -> ProfileDraft? {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [MyProfileRow] = try await client.rpc("get_my_profile").execute().value
        guard let row = rows.first else { return nil }
        var draft = ProfileDraft()
        draft.name = row.name
        draft.birthDate = row.birthDate
        draft.gender = ProfileGender(rawValue: row.gender)
        draft.relationshipIntent = RelationshipIntent(rawValue: row.relationshipIntent) ?? .both
        draft.university = row.university
        draft.department = row.department
        draft.year = row.academicYear
        draft.bio = row.bio
        draft.badge = await myBadge()
        draft.interests = Set(row.interests)
        var filters = DiscoveryFilters()
        filters.minimumAge = row.minAge
        filters.maximumAge = row.maxAge
        filters.academicYears = Set(row.academicYears)
        filters.departments = Set(row.departments)
        filters.requiresCommonInterest = row.requireCommonInterest
        filters.campusOnly = row.campusOnly
        draft.discoveryFilters = filters
        draft.ghostMode = row.ghostMode
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
        let paths = [profile.avatarPath].compactMap { $0 } + gallery.map(\.storagePath)
        let urls = await signedURLs(bucket: "profile-photos", paths: paths)
        return ProfilePhotosResult(
            avatarURL: profile.avatarPath.flatMap { urls[$0] },
            galleryURLs: gallery.compactMap { urls[$0.storagePath] }
        )
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
        return publicProfilePhotoURL(path)
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
            if let url = publicProfilePhotoURL(path) { urls.append(url) }
        }
        return urls
    }

    func blockUser(_ profileID: UUID) async throws {
        // Runs as a security definer RPC so the same call also ends any live match —
        // direct client writes to `matches` aren't granted, and leaving a severed
        // block's match untouched would let the conversation reappear after a refresh.
        try await client.rpc("block_user", params: BlockParams(target: profileID)).execute()
    }

    /// Engellediğin kişiler.
    ///
    /// İki adım: önce kendi engel kayıtların (`blocks` üzerinde `blocker_id =
    /// auth.uid()` kuralıyla okunuyor), sonra o kimliklere ait profiller.
    /// İkinci sorgu bazılarını döndürmeyebilir — profil görünürlük kuralı
    /// "engellediğim kişi" durumunu kapsamıyor. Eksik gelenler listeden
    /// düşmüyor; adsız görünüyorlar ama engelleri kaldırılabiliyor.
    func fetchBlockedProfiles() async throws -> [BlockedProfile] {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let rows: [BlockRow] = try await client
            .from("blocks")
            .select("blocked_id,created_at")
            .eq("blocker_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }

        let profiles: [SupabaseProfileRow] = (try? await client
            .from("profiles")
            .select("id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified")
            .in("id", values: rows.map(\.blockedID))
            .execute()
            .value) ?? []
        let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let urlMap = await signedURLs(bucket: "profile-photos", paths: profiles.compactMap(\.avatarPath))

        return rows.map { row in
            let profil = byID[row.blockedID]
            return BlockedProfile(
                id: row.blockedID,
                name: profil?.name,
                imageURL: profil?.avatarPath.flatMap { urlMap[$0] },
                blockedAt: row.createdAt
            )
        }
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
    /// Anlık mesaj akışı. Bağlantı koptuğunda ya da hiç kurulamadığında kendi kendine
    /// yeniden bağlanır.
    ///
    /// Önceden tek denemeydi: `subscribeWithError()` hata verirse ya da soket düşerse
    /// akış sessizce bitiyordu. `AppState` tarafındaki dinleyici görevi de tamamlanmış
    /// haliyle duruyor ve `startMessageListener` içindeki `guard messageListenerTask == nil`
    /// yüzünden bir daha hiç başlatılmıyordu. Yani tek bir ağ kesintisi, uygulama
    /// kapatılıp açılana kadar canlı mesajlaşmayı tamamen bitiriyordu — mesajlaşma
    func recordProfileVisit(_ profileID: UUID) async throws {
        try await client.rpc("record_profile_visit", params: ProfileVisitParams(target: profileID)).execute()
    }

    func setGhostMode(_ enabled: Bool) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("set_ghost_mode", params: GhostModeParams(enabled: enabled)).execute()
    }

    func fetchProfileVisits() async throws -> [ProfileVisit] {
        let rows: [ProfileVisitRow] = try await client.rpc("get_my_profile_visits").execute().value
        let avatarURLs = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.avatarPath))
        return rows.map { row in
            let age = max(18, Calendar.current.dateComponents([.year], from: row.birthDate, to: .now).year ?? 18)
            let profile = StudentProfile(
                id: row.visitorID, name: row.name, age: age, university: row.university,
                department: row.department, year: row.academicYear, bio: row.bio,
                interests: [], imageURL: row.avatarPath.flatMap { avatarURLs[$0] },
                compatibility: 0, isVerified: row.isVerified, badge: row.badge ?? .none
            )
            return ProfileVisit(profile: profile, visitedAt: row.lastVisitedAt)
        }
    }

    func fetchPersonDetails(_ profileID: UUID) async throws -> PersonDetails {
        // İzin kuralları bu iki tabloyu "profil görünüyorsa okunur" diye
        // tanımlıyor, dolayısıyla ek bir sunucu değişikliği gerekmiyor.
        // Üç sorgu + imza + rozet paralel; gönderiler ayrı çağrıda — aksi halde
        // profil açılınca fotoğraflar post indirmelerini bekliyordu.
        async let interestRowsTask: [ProfileInterestRow] = (try? await client
            .from("profile_interests")
            .select("interest")
            .eq("profile_id", value: profileID)
            .execute()
            .value) ?? []
        async let photoRowsTask: [ProfilePhotoRow] = (try? await client
            .from("profile_photos")
            .select("storage_path,position")
            .eq("profile_id", value: profileID)
            .order("position", ascending: true)
            .execute()
            .value) ?? []
        // Navigasyondaki kart bazen imzasız / boş avatar getiriyor; burada
        // `avatar_path`'i yeniden okuyup imzalıyoruz.
        async let mediaTask: ProfileMediaRow? = try? await client
            .from("profiles")
            .select("avatar_path")
            .eq("id", value: profileID)
            .single()
            .execute()
            .value
        async let badgeTask = badges(for: [profileID])[profileID]

        let interestRows = await interestRowsTask
        let photoRows = await photoRowsTask
        let media = await mediaTask
        let paths = photoRows.map(\.storagePath) + [media?.avatarPath].compactMap { $0 }
        let urls = await signedURLs(bucket: "profile-photos", paths: paths)
        return PersonDetails(
            interests: interestRows.map(\.interest).sorted(),
            galleryURLs: photoRows.compactMap { urls[$0.storagePath] },
            avatarURL: media?.avatarPath.flatMap { urls[$0] },
            badge: await badgeTask,
            posts: []
        )
    }

    /// Profil gönderi ızgarası. Medya indirme yok — imzalı URL ile AsyncImage.
    func fetchPersonPosts(_ profileID: UUID) async -> [BackendPost] {
        await posts(byAuthor: profileID)
    }

    /// Bir kişinin gönderileri. Akıştaki sorgunun aynısı, tek bir yazarla
    /// sınırlanmış hali.
    func posts(byAuthor profileID: UUID) async -> [BackendPost] {
        let rows: [PostRow] = (try? await client
            .from("posts")
            .select("id,author_id,caption,media_path,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,avatar_path,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name,avatar_path))")
            .eq("author_id", value: profileID)
            .order("created_at", ascending: false)
            .limit(30)
            .execute()
            .value) ?? []
        guard !rows.isEmpty else { return [] }
        // Yorum yazarlarının fotoğrafları da aynı toplu imzalamaya giriyor;
        // satır başına ayrı istek atmamak için.
        let avatarURLs = await signedURLs(
            bucket: "profile-photos",
            paths: rows.compactMap { $0.author.avatarPath }
                + rows.flatMap { $0.comments }.compactMap { $0.author.avatarPath }
        )
        let mediaURLs = await signedURLs(
            bucket: "post-media",
            paths: rows.compactMap(\.mediaPath)
        )
        let likeRows: [PostLikeRow] = ((try? await client
            .from("post_likes")
            .select("post_id,user_id")
            .`in`("post_id", values: rows.map(\.id))
            .execute()
            .value) ?? [])
        let savedIDs: Set<UUID> = Set(((try? await client
            .from("saved_posts")
            .select("post_id")
            .`in`("post_id", values: rows.map(\.id))
            .execute()
            .value) as [SavedPostRow]? ?? []).map(\.postID))
        let authorBadge = await badges(for: [profileID])[profileID] ?? .none
        let userID = currentUserID
        return rows.map { row in
            let postLikes = likeRows.filter { $0.postID == row.id }
            return row.backendPost(
                imageData: nil,
                authorAvatarURL: row.author.avatarPath.flatMap { avatarURLs[$0] },
                likeCount: postLikes.count,
                liked: userID.map { id in postLikes.contains { $0.userID == id } } ?? false,
                saved: savedIDs.contains(row.id),
                badge: authorBadge,
                commentAvatarURLs: avatarURLs,
                imageURL: row.mediaPath.flatMap { mediaURLs[$0] }
            )
        }
    }
}

private struct BlockRow: Decodable {
    let blockedID: UUID
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case blockedID = "blocked_id"
        case createdAt = "created_at"
    }
}
