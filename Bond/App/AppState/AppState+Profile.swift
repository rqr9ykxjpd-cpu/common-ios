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
            posts: [],
            username: uzak.username,
            cardTheme: uzak.cardTheme
        )
    }

    /// Eski hesaplara ve Build 5 ile açılanlara kullanıcı adı otomatik verildi;
    /// bir kez sorup onaylatıyoruz. Okunamazsa sormuyoruz.
    func checkUsernameChoice() async {
        needsUsernameChoice = (try? await service.usernameNeedsChoice()) ?? false
    }

    /// Seçme ekranından: adı alır (aynı ad da olabilir, onay yerine geçer).
    func chooseUsername(_ candidate: String) async -> Bool {
        do {
            try await service.claimUsername(candidate)
            draft.username = candidate
            persistAccount()
            // Ekranı çağıran kapatıyor (düğmedeki ✓'den sonra).
            show(L10n.Username.chosen)
            Haptics.success()
            return true
        } catch {
            showError(UsernameError.from(error) ?? error, fallback: L10n.Username.checkFailed)
            return false
        }
    }

    /// Kartın rengini tek başına okur ve hatırlar (bkz. `CardThemeReading`).
    func loadCardTheme(for profileID: UUID) async {
        guard let okuyucu = service as? any CardThemeReading,
              let tema = try? await okuyucu.fetchCardTheme(profileID) else { return }
        cardThemes[profileID] = tema
    }

    /// Profil kartının rengini kaydeder. Başarılıysa taslağa da yazar ki kendi
    /// kartın ve düzenleyici hemen yeni renkle açılsın.
    @discardableResult
    func saveCardTheme(_ theme: CardTheme) async -> Bool {
        do {
            try await service.setCardTheme(theme)
            draft.cardTheme = theme
            cardThemes[currentUserID] = theme
            persistAccount()
            show(L10n.CardStudio.saved)
            Haptics.success()
            return true
        } catch {
            showError(error, fallback: L10n.CardStudio.failed)
            return false
        }
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

    func saveProfile(_ updatedDraft: ProfileDraft, avatar: Data?, gallery: [Data]?) async -> Bool {
        var updatedDraft = updatedDraft
        // Görünen ad boş bırakıldıysa kullanıcı adı görünür; sunucuda ad zorunlu.
        if updatedDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updatedDraft.name = updatedDraft.username
        }
        do {
            // Önce kullanıcı adı: alınmışsa hiçbir şey yarım kaydedilmesin.
            // Düzenleme ekranında profil satırı zaten var.
            if updatedDraft.username != draft.username {
                try await service.claimUsername(updatedDraft.username)
            }
            try await service.saveProfile(updatedDraft)
        } catch let error as UsernameError {
            showError(error.errorDescription ?? L10n.Profile.saveFailed)
            return false
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
        var avatarFailed = false
        var galleryFailed = false
        if let avatar {
            do {
                // `nil` artık "değiştirme" demek, "sil" değil. Düzenleme ekranı mevcut
                // fotoğrafı sunucudan indirerek dolduruyor; indirme başarısız olduğunda
                // (ağ koptuğunda ya da imzalı adres süresi dolduğunda) elinde nil kalıyor
                // ve sırf bio değiştirmek için kaydeden kişinin profil fotoğrafı sessizce
                // siliniyordu. Silme seçeneği hiçbir yerde sunulmuyor: fotoğraf zorunlu.
                avatarURL = try await service.updateAvatar(avatar)
                if avatarURL != nil { avatarData = nil }
            } catch {
                avatarFailed = true
                avatarData = avatar
            }
        }

        if let gallery {
            do {
                galleryURLs = try await service.updateGallery(gallery)
                // İmzalı URL üretimi geçici olarak başarısızsa yeni fotoğrafları
                // ekranda tut; veritabanı değişimi yine başarıyla tamamlanmıştır.
                profileGalleryData = galleryURLs.isEmpty && !gallery.isEmpty ? gallery : []
            } catch {
                galleryFailed = true
                profileGalleryData = gallery
            }
        }

        persistAccount()
        let photoFailed = avatarFailed || galleryFailed
        if photoFailed {
            showError(L10n.Profile.photosPartialFail)
        } else {
            show(L10n.Profile.updated)
            Haptics.success()
        }
        // Fotoğraf başarısızsa editör açık kalır; kullanıcı seçtiği görselleri
        // kaybetmeden yeniden deneyebilir. Metin alanları zaten güvenle kaydedildi.
        return !photoFailed
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
            let ok = await publishPost(images: [image], caption: "", place: nil, announces: false)
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
        // Kilitliyken kimsenin "Profilini görüntüleyenler"inde görünmesin.
        guard !isEduLocked else { return }
        guard profile.id != currentUserID else { return }
        Task { try? await service.recordProfileVisit(profile.id) }
    }

    /// Kayıt ve profil düzenleme ekranındaki anlık kontrol.
    func isUsernameAvailable(_ candidate: String) async throws -> Bool {
        try await service.isUsernameAvailable(candidate)
    }
}
