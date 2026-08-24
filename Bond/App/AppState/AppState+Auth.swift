import SwiftUI

// MARK: - AppState+Auth
extension AppState {
    /// Apple'ın verdiği ham (hash'lenmemiş) nonce'u geçir; `SupabaseProductService` bunu
    /// olduğu gibi Supabase'e iletir, hash'lenmiş hali yalnızca Apple'a giden istekte kullanılır.
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        do {
            try await service.signInWithApple(idToken: idToken, nonce: nonce)
        } catch {
            showError(error, fallback: L10n.Auth.appleFailed)
            return false
        }
        return await completeSocialSignIn()
    }

    @discardableResult
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String) async -> Bool {
        do {
            try await service.signInWithGoogle(idToken: idToken, accessToken: accessToken, nonce: nonce)
        } catch {
            showError(error, fallback: L10n.Auth.googleFailed)
            return false
        }
        return await completeSocialSignIn()
    }

    /// E-posta adresine giriş bağlantısı gönderir.
    @discardableResult
    func requestEmailSignInLink(_ rawEmail: String) async -> Bool {
        let normalized = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            try await service.requestEmailSignInLink(email: normalized)
        } catch {
            showError(error, fallback: L10n.Auth.linkFailed)
            return false
        }
        return true
    }

    /// `.onOpenURL` ile yakalanan giriş bağlantısını tamamlar. Apple/Google'la aynı
    /// sonrası akışı paylaşır (`completeSocialSignIn`).
    func completeEmailSignIn(url: URL) async {
        do {
            try await service.completeEmailSignIn(url: url)
        } catch {
            showError(error, fallback: L10n.Auth.signInIncomplete)
            return
        }
        _ = await completeSocialSignIn()
    }

    /// Apple/Google ikisi de aynı sonrası akışı paylaşır: yeni hesapsa onboarding'e,
    /// profili tamamlanmışsa doğrudan uygulamaya geçer.
    /// Girişin kendisi başarılı olduktan sonrası. Buradaki bir hata "giriş yapılamadı"
    /// değildir — oturum açıldı, profil yüklenemedi. Önceden ikisi tek `catch`'te
    /// birleşiyordu ve profil çözümlenemediğinde kullanıcıya "Google ile giriş
    /// yapılamadı" deniyordu; sebebi bambaşka bir yerdeyken yanlış yere baktırıyordu.
    func completeSocialSignIn() async -> Bool {
        await BondImageLoader.shared.reset()
        currentUserID = service.currentUserID ?? currentUserID
        if let sessionEmail = service.currentUserEmail {
            email = sessionEmail.lowercased()
        }
        restoreOrCreateAccount(for: email)
        await subscriptions.identify(userID: currentUserID)

        let profile: ProfileDraft?
        do {
            profile = try await service.fetchMyProfile()
        } catch {
            showError(error, fallback: L10n.Auth.profileLoadFailed)
            return false
        }
        guard let profile else {
            persistSession()
            withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.identity) }
            return true
        }
        applyRemoteProfile(profile)
        persistSession()
        let fotograflarOkundu = await loadMyProfilePhotos()
        await loadNotifications()
        await loadPlaces(silently: true)
        await loadStories()
        await loadClubs(silently: true)
        await loadMeetingRequests()
        await loadMessageRequests(silently: true)
        await loadProfileVisits(silently: true)
        try? await service.touchLastActive()
        startMessageListener()
        await refreshSubscriptions()
        await startPushRegistration()
        if requiresAvatarStep(photosLoaded: fotograflarOkundu) {
            withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.photo) }
            return true
        }
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        show(name.isEmpty ? L10n.Auth.welcome : L10n.Auth.welcomeName(name))
        return true
    }
    func restoreBackendSession() async {
#if DEBUG
        if skipsSessionRestore { return }
#endif
        do {
            guard let userID = try await service.restoreSession() else {
                // Sunucu oturumu bitmiş. Yerel bayrağı da düşürmezsek uygulama her açılışta
                // önce `.app`'e girip hemen geri atıyor.
                defaults.set(false, forKey: SessionKey.isSignedIn)
                if route == .app { route = .welcome }
                return
            }
            currentUserID = userID
            await subscriptions.identify(userID: currentUserID)
            // Uygulama silinip yeniden kurulduğunda yerel kayıt sıfırlanır ama Supabase oturumu
            // Keychain'de kaldığı için hâlâ geçerlidir. E-postayı oturumdan geri almazsak
            // `persistSession` boş e-posta yüzünden hiçbir şey yazmaz ve kullanıcı geçerli bir
            // oturumla karşılama ekranında mahsur kalır.
            if email.isEmpty, let sessionEmail = service.currentUserEmail {
                email = sessionEmail.lowercased()
            }

            let profile = try await service.fetchMyProfile()
            guard let profile else {
                // Oturum var ama profil yok: kayıt akışı yarıda kalmış.
                showError(L10n.Auth.completeProfile)
                withAnimation(.smooth(duration: 0.45)) { route = .onboarding(.identity) }
                return
            }
            applyRemoteProfile(profile)
            if !email.isEmpty { persistSession() }
            let fotograflarOkundu = await loadMyProfilePhotos()
            await loadNotifications()
            await loadPlaces(silently: true)
            await loadStories()
            await loadClubs(silently: true)
            await loadMeetingRequests()
            await loadMessageRequests(silently: true)
            await loadProfileVisits(silently: true)
            try? await service.touchLastActive()
            startMessageListener()
            await refreshSubscriptions()
            // Geçerli oturum ve tamamlanmış profil varken karşılama ekranında bırakmak
            // kullanıcıyı hiçbir yere gidemez halde bırakıyordu.
            if requiresAvatarStep(photosLoaded: fotograflarOkundu) {
                withAnimation(.smooth(duration: 0.45)) { route = .onboarding(.photo) }
            } else if route != .app {
                withAnimation(.smooth(duration: 0.45)) { route = .app }
            }
            await startPushRegistration()
        } catch {
            // Ağın kopması oturumun bittiği anlamına gelmiyor. Kampüs wifi'ında bir istek
            // zaman aşımına uğradığında kullanıcıyı karşılama ekranına atmak, girişi
            // düşmüş gibi gösteriyordu; oysa oturum Keychain'de duruyor ve profil de
            // yerelde önbellekli. Kullanıcıyı olduğu yerde bırakıp durumu söylüyoruz.
            if isNetworkFailure(error) {
                showError(error, fallback: L10n.Auth.connectionFailed)
            } else {
                route = .welcome
                showError(error, fallback: L10n.Auth.sessionRestoreFailed)
            }
        }
    }

    /// Sunucudaki profili yerel duruma yazar. `draft` yalnızca UserDefaults'tan geldiği için
    /// kullanıcı başka bir cihazdan girdiğinde profili sunucuda dururken boş görünüyordu.
    func applyRemoteProfile(_ profile: ProfileDraft) {
        draft = profile
#if DEBUG
        myBadge = debugBadgeOverride ?? profile.badge
#else
        myBadge = profile.badge
#endif
        discoveryFilters = profile.discoveryFilters
        persistAccount()
        applyRemoteGhostMode(profile.ghostMode)
    }

    /// Sunucu hayalet kolonunu gönderdiyse o kaynak. Yerelde açık, sunucuda
    /// kapalıysa (kolon yeni eklendi) tercihi bir kez yukarı yazarız; aksi
    /// halde eski cihaz tercihi sessizce kapanırdı.
    private func applyRemoteGhostMode(_ remote: Bool?) {
        guard let remote else { return }
        if remote {
            ghostMode = true
            draft.ghostMode = true
            return
        }
        if ghostMode {
            Task { await persistGhostMode(true) }
        } else {
            ghostMode = false
            draft.ghostMode = false
        }
    }

    func setGhostMode(_ enabled: Bool) {
        guard enabled == false || tier.hasGhostMode else { return }
        let previous = ghostMode
        ghostMode = enabled
        draft.ghostMode = enabled
        Haptics.impact(.light)
        Task { await persistGhostMode(enabled, revertingTo: previous) }
    }

    private func persistGhostMode(_ enabled: Bool, revertingTo previous: Bool? = nil) async {
        do {
            try await service.setGhostMode(enabled)
        } catch {
            if let previous {
                ghostMode = previous
                draft.ghostMode = previous
                showError(error, fallback: L10n.Profile.ghostSaveFailed)
            }
        }
    }

    /// Başarılıysa `true`. Çağıran taraf "fotoğrafı yok" ile "fotoğrafını okuyamadım"
    /// arasını ayırabilsin diye: ikisini karıştırmak, ağ koptuğunda fotoğrafı olan
    /// kullanıcıyı fotoğraf adımına hapsediyor.
    @discardableResult
    func loadMyProfilePhotos() async -> Bool {
        do {
            let result = try await service.fetchMyProfilePhotos()
            avatarURL = result.avatarURL
            galleryURLs = result.galleryURLs
            return true
        } catch {
            showError(error, fallback: L10n.Auth.photosLoadFailed)
            return false
        }
    }

    /// Fotoğraf zorunlu. Eski sürümlerde "şimdilik atla" ile geçilmiş ya da bir şekilde
    /// fotoğrafsız kalmış hesaplar uygulamaya değil, fotoğraf adımına düşer.
    func requiresAvatarStep(photosLoaded: Bool) -> Bool {
        photosLoaded && avatarURL == nil && avatarData == nil
    }
    func signOut() async {
        guard !isAccountActionInProgress else { return }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        persistAccount()
        do {
            await unregisterPushToken()
            await BondImageLoader.shared.reset()
            try await service.signOut()
            clearSession(keepAccountData: true)
        } catch {
            showError(error, fallback: L10n.Auth.signOutFailed)
        }
    }

    func deleteAccount() async {
        guard !isAccountActionInProgress else { return }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        do {
            await BondImageLoader.shared.reset()
            try await service.deleteAccount()
            clearSession(keepAccountData: false)
        } catch {
            showError(error, fallback: L10n.Auth.deleteFailed)
        }
    }

    func clearSession(keepAccountData: Bool) {
        stopMessageListener()
        Task { await subscriptions.resetIdentity() }
        let accountID = currentUserID
        if !keepAccountData {
            for key in ["email", "profileDraft", "avatar", "gallery"] {
                defaults.removeObject(forKey: SessionKey.account(key, userID: accountID))
            }
            for legacyKey in [SessionKey.accountEmail, SessionKey.profileDraft, SessionKey.avatar, SessionKey.gallery] {
                defaults.removeObject(forKey: legacyKey)
            }
        }
        defaults.set(false, forKey: SessionKey.isSignedIn)
        defaults.removeObject(forKey: SessionKey.email)
        defaults.removeObject(forKey: SessionKey.userID)
        email = ""
        currentUserID = UUID()
        draft = ProfileDraft()
        discoveryFilters = DiscoveryFilters()
        avatarData = nil
        profileGalleryData = []
        avatarURL = nil
        galleryURLs = []
        profiles = []
        conversations = []
        posts = []
        stories = []
        notifications = []
        pendingNotificationReadIDs = []
        meetingRequests = []
        profileVisits = []
        currentMatch = nil
        selectedConversation = nil
        selectedStory = nil
        selectedPlaceFilter = nil
        currentVisiblePlace = nil
        joinedClubIDs = []
        myBadge = .none

        // Geçici bayraklar da sıfırlanmalı. Çıkış bir yükleme sürerken yapılırsa
        // `isLoadingDiscovery` true kalıyor ve sonraki girişte `loadDiscovery`
        // başındaki guard yüzünden keşif hiç yüklenmiyordu.
        isLoadingDiscovery = false
        isReactingToProfile = false
        isFinishingOnboarding = false
        onboardingFailure = nil
        discoveryError = nil
        toast = nil

        // `places`, `clubs` herkese açık referans verisi; `appearance` kullanıcının
        // cihaz tercihi. Bunlar kasıtlı olarak korunuyor.
        route = .welcome
        Haptics.success()
    }

    func restoreOrCreateAccount(for signedInEmail: String) {
        if let backendUserID = service.currentUserID {
            currentUserID = backendUserID
        }
        defaults.set(signedInEmail, forKey: SessionKey.account("email", userID: currentUserID))
        loadAccountData(migratingLegacy: true)
    }

    func loadAccountData(migratingLegacy: Bool) {
        let draftKey = SessionKey.account("profileDraft", userID: currentUserID)
        let avatarKey = SessionKey.account("avatar", userID: currentUserID)
        let galleryKey = SessionKey.account("gallery", userID: currentUserID)
        let legacyUserID = defaults.string(forKey: SessionKey.userID).flatMap(UUID.init(uuidString:))
        let canMigrateLegacy = migratingLegacy && legacyUserID == currentUserID
        let storedDraft = defaults.data(forKey: draftKey) ?? (canMigrateLegacy ? defaults.data(forKey: SessionKey.profileDraft) : nil)
        if let storedDraft, let savedDraft = try? JSONDecoder().decode(ProfileDraft.self, from: storedDraft) { draft = savedDraft }
        discoveryFilters = draft.discoveryFilters
        // Avatar/galeri artık Supabase Storage'da yaşıyor (bkz. loadMyProfilePhotos), UserDefaults
        // ham görsel verisi için tasarlanmadığından burada yalnızca eski kayıtları temizliyoruz.
        defaults.removeObject(forKey: avatarKey)
        defaults.removeObject(forKey: galleryKey)
        if canMigrateLegacy, defaults.data(forKey: draftKey) == nil { persistAccount() }
    }

    func persistAccount() {
        guard !email.isEmpty else { return }
        defaults.set(currentUserID.uuidString, forKey: SessionKey.userID)
        defaults.set(email.lowercased(), forKey: SessionKey.account("email", userID: currentUserID))
        defaults.set(try? JSONEncoder().encode(draft), forKey: SessionKey.account("profileDraft", userID: currentUserID))
    }
    func persistSession() {
        defaults.set(true, forKey: SessionKey.isSignedIn)
        defaults.set(email, forKey: SessionKey.email)
        persistAccount()
    }
}
