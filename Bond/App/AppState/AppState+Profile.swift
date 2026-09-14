import SwiftUI

// MARK: - AppState+Profile
extension AppState {
    /// Gönderi ve story sorguları yazar için yalnızca temel alanları getiriyor.
    /// Kişinin profiline girildiğinde ilgi alanları ve galerisi bu yüzden boştu.
    /// Fotoğraflar önce gelir; gönderiler `personPosts` ile ayrı yüklenir.
    func personDetails(for profileID: UUID) async -> PersonProfileData? {
        guard let uzak = try? await service.fetchPersonDetails(profileID) else { return nil }
        return PersonProfileData(
            interests: uzak.interests,
            galleryURLs: uzak.galleryURLs,
            avatarURL: uzak.avatarURL,
            badge: uzak.badge,
            posts: []
        )
    }

    func personPosts(for profileID: UUID) async -> [SocialPost] {
        await service.fetchPersonPosts(profileID).map { socialPost(from: $0) }
    }

    var currentUserPosts: [SocialPost] {
        posts.filter(\.isMine)
    }

    var currentUserProfile: StudentProfile {
        // Yedek ad "Cem"di: adını henüz girmemiş bir kullanıcı kendini başkasının
        // adıyla görüyordu. Rozet de aktarılmıyordu.
        StudentProfile(
            id: currentUserID,
            name: draft.name.isEmpty ? L10n.Common.you : draft.name,
            age: draft.age,
            university: draft.university,
            department: draft.department.isEmpty ? L10n.Common.student : draft.department,
            year: draft.year,
            bio: draft.bio,
            interests: Array(draft.interests).sorted(),
            imageURL: avatarURL,
            galleryImageURLs: galleryURLs,
            isVerified: true,
            badge: myBadge
        )
    }

    var galleryCount: Int { max(galleryURLs.count, profileGalleryData.count) }
    var isGalleryFull: Bool { galleryCount >= CampusLimits.maxGalleryPhotos }

    var profileCompletion: Int {
        draft.completionPercent(hasAvatar: avatarData != nil || avatarURL != nil)
    }

    func saveProfile(_ updatedDraft: ProfileDraft, avatar: Data?, gallery: [Data]) async -> Bool {
        do {
            try await service.saveProfile(updatedDraft)
        } catch {
            showError(error, fallback: L10n.Profile.saveFailed)
            return false
        }

        draft = updatedDraft
        if avatar != nil { avatarData = avatar }

        // Fotoğraf yüklemesi metin kaydından ayrı. Aynı `do` bloğundayken bir fotoğraf
        // hatası üç şeyi birden bozuyordu: metinler sunucuya yazılmış olmasına rağmen
        // "kaydedilemedi" deniyor, `persistAccount()` hiç çalışmadığı için yerel kayıt
        // sunucudan farklı kalıyor ve ekran kapanmadığı için kullanıcı baştan deniyordu.
        var photoFailed = false
        do {
            // `nil` artık "değiştirme" demek, "sil" değil. Düzenleme ekranı mevcut
            // fotoğrafı sunucudan indirerek dolduruyor; indirme başarısız olduğunda
            // (ağ koptuğunda ya da imzalı adres süresi dolduğunda) elinde nil kalıyor
            // ve sırf bio değiştirmek için kaydeden kişinin profil fotoğrafı sessizce
            // siliniyordu. Silme seçeneği hiçbir yerde sunulmuyor: fotoğraf zorunlu.
            if let avatar {
                avatarURL = try await service.updateAvatar(avatar)
            }
            galleryURLs = try await service.updateGallery(gallery)
        } catch {
            photoFailed = true
        }

        if !photoFailed {
            // Gösterim imzalı URL + BondImageLoader; ham JPEG oturumda kalmasın.
            if avatarURL != nil { avatarData = nil }
            if galleryURLs.isEmpty, !gallery.isEmpty {
                profileGalleryData = gallery
            } else {
                profileGalleryData = []
            }
        } else {
            profileGalleryData = gallery
        }

        persistAccount()
        if photoFailed {
            showError(L10n.Profile.photosPartialFail)
        } else {
            show(L10n.Profile.updated)
            Haptics.success()
        }
        return true
    }

    func appendGalleryPhoto(_ image: Data) async -> Bool {
        guard !isGalleryFull else {
            show(L10n.Composer.galleryFull)
            return false
        }
        do {
            let url = try await service.appendGalleryPhoto(image)
            galleryURLs.append(url)
            persistAccount()
            return true
        } catch {
            showError(error, fallback: L10n.Profile.photosPartialFail)
            return false
        }
    }

    func publishPhotosAsPosts(_ images: [Data]) async {
        guard !images.isEmpty else { return }
        var hitLimit = false
        for image in images {
            if let cap = tier.maxPosts, currentUserPosts.count >= cap {
                hitLimit = true
                break
            }
            let ok = await publishPost(imageData: image, caption: "", place: nil, announces: false)
            if !ok { return }
        }
        if hitLimit, !paywallVisible {
            show(L10n.Composer.postLimit(CampusLimits.maxPostsPerUser))
        }
    }

    func loadProfileVisits(silently: Bool = false) async {
        do {
            profileVisits = try await service.fetchProfileVisits()
        } catch {
            if !silently { showError(error, fallback: L10n.Profile.visitorsLoadFailed) }
        }
    }

    /// Birinin profili kasıtlı olarak açıldığında çağrılır.
    func recordProfileVisit(_ profile: StudentProfile) {
        guard !(ghostMode && tier.hasGhostMode) else { return }
        guard profile.id != currentUserID else { return }
        Task { try? await service.recordProfileVisit(profile.id) }
    }
}
