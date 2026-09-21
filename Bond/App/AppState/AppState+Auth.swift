import SwiftUI
import AuthenticationServices

// MARK: - AppState+Auth
extension AppState {
    /// Apple'ın verdiği ham (hash'lenmemiş) nonce'u geçir; `SupabaseProductService` bunu
    /// olduğu gibi Supabase'e iletir, hash'lenmiş hali yalnızca Apple'a giden istekte kullanılır.
    /// `providerName`: Apple/Google'ın verdiği ad. Kayıt adımında ad alanı bununla
    /// dolu gelir; Apple girişinden sonra adı yeniden sormak App Review'de
    /// Guideline 4 (Sign in with Apple) reddine yol açıyordu.
    @discardableResult
    func signInWithApple(idToken: String, nonce: String, providerName: String? = nil) async -> Bool {
        pendingProviderName = providerName?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await service.signInWithApple(idToken: idToken, nonce: nonce)
            // A new Apple authorization grants permission again, so an old
            // partial-deletion marker must not skip revocation on the next try.
            if let userID = service.currentUserID,
               appleRevokedPendingDeletionUserID == userID {
                appleRevokedPendingDeletionUserID = nil
            }
        } catch {
            showError(error, fallback: L10n.Auth.appleFailed)
            return false
        }
        return await completeSocialSignIn()
    }

    @discardableResult
    func signInWithGoogle(idToken: String, accessToken: String, nonce: String, providerName: String? = nil) async -> Bool {
        pendingProviderName = providerName?.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// E-posta ve şifre. Debug derlemesindeki demo hesaplar için.
    @discardableResult
    func signInWithEmail(_ rawEmail: String, password: String) async -> Bool {
        let normalized = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            try await service.signInWithEmail(email: normalized, password: password)
        } catch {
            showError(error, fallback: L10n.Auth.passwordFailed)
            return false
        }
        return await completeSocialSignIn()
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
            // Sunucuda profil yok: kayıt adımı. Sağlayıcı ad verdiyse alan dolu gelir.
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let ad = pendingProviderName, !ad.isEmpty {
                draft.name = ad
            }
            pendingProviderName = nil
            persistSession()
            withAnimation(.smooth(duration: 0.55)) { route = .onboarding(.identity) }
            return true
        }
        pendingProviderName = nil
        applyRemoteProfile(profile)
        persistSession()
        let fotograflarOkundu = await loadMyProfilePhotos()
        await loadNotifications()
        await loadPlaces(silently: true)
        await loadStories()
        await loadClubs(silently: true)
        await loadMeetingRequests()
        await loadStudyGroups(silently: true)
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
            await loadStudyGroups(silently: true)
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

    var hasAppleIdentity: Bool {
        hasPendingAppleRevokedDeletion || ((service as? any AppleAccountRevocationService)?.hasAppleIdentity ?? false)
    }

    var hasPendingAppleRevokedDeletion: Bool {
        route != .welcome && appleRevokedPendingDeletionUserID == currentUserID
    }

    func revokeAppleAuthorization(_ request: AppleAccountRevocationRequest) async throws {
        guard let appleService = service as? any AppleAccountRevocationService else {
            throw AppleAccountRevocationError.unavailable
        }
        guard !isAccountActionInProgress else { throw AppleAccountRevocationError.unavailable }
        let accountID = service.currentUserID
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        try await appleService.revokeAppleAuthorization(request)
        if let accountID, service.currentUserID == accountID {
            // No provider token is stored. Keep only the deletion intent so a
            // failed RPC can be retried after closing the sheet or restarting.
            appleRevokedPendingDeletionUserID = accountID
        }
    }

    /// A notification during our deletion flow must not clear the Supabase
    /// session before delete_my_account executes. Outside that flow, revoked
    /// Apple credentials invalidate the local authenticated UI.
    func handleAppleCredentialRevocation() async {
        guard !isAccountActionInProgress, !hasPendingAppleRevokedDeletion,
              let apple = service as? any AppleAccountRevocationService,
              let subject = apple.appleSubject else { return }
        let accountID = service.currentUserID
        let state: ASAuthorizationAppleIDProvider.CredentialState? = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: subject) { state, error in
                continuation.resume(returning: error == nil ? state : nil)
            }
        }
        guard !isAccountActionInProgress, !hasPendingAppleRevokedDeletion, service.currentUserID == accountID,
              state == .revoked || state == .notFound else { return }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        await BondImageLoader.shared.reset()
        try? await service.signOut()
        clearSession(keepAccountData: false)
    }

    @discardableResult
    func deleteAccount(manualAppleRevocation: Bool = false) async -> Bool {
        guard !isAccountActionInProgress else { return false }
        isAccountActionInProgress = true
        defer { isAccountActionInProgress = false }
        do {
            let accountID = service.currentUserID
            await BondImageLoader.shared.reset()
            try await service.deleteAccount()
            if let accountID,
               appleRevokedPendingDeletionUserID == accountID {
                appleRevokedPendingDeletionUserID = nil
            }
            clearSession(keepAccountData: false)
            // Only claim success after the actual account deletion. The manual
            // path never claims that the Apple permission was revoked as well.
            if manualAppleRevocation {
                UserDefaults.standard.set(true, forKey: AppleAccountDeletionNotice.defaultsKey)
            }
            return true
        } catch {
            showError(error, fallback: L10n.Auth.deleteFailed)
            return false
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
        avatarData = nil
        profileGalleryData = []
        avatarURL = nil
        galleryURLs = []
        conversations = []
        posts = []
        stories = []
        notifications = []
        pendingNotificationReadIDs = []
        rightSwipedProfileIDs = []
        introductionRequests = []
        introductionRequestsError = nil
        isLoadingIntroductions = false
        meetingRequests = []
        profileVisits = []
        selectedConversation = nil
        selectedStory = nil
        selectedPlaceFilter = nil
        currentVisiblePlace = nil
        presenceUpdateID = nil
        presenceUpdatingPlaceID = nil
        presenceError = nil
        feedLoadGeneration += 1
        clubsLoadGeneration += 1
        isLoadingFeed = false
        isLoadingClubs = false
        feedError = nil
        clubsError = nil
        joinedClubIDs = []
        studyGroups = []
        eduStatus = nil
        myBadge = .none
        serverPlan = .free
        tier = subscriptions.tier

        isFinishingOnboarding = false
        onboardingFailure = nil
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

    /// Eski kaydırma/cinsiyet/keşif kayıtlarını ve görsel önbelleği bir kez siler.
    /// Giriş oturumuna dokunmaz; profil taslağını yeni şemayla yeniden yazar.
    func purgeLegacyProductCacheIfNeeded() {
        let stored = defaults.integer(forKey: SessionKey.productCacheEpoch)
        guard stored < SessionKey.currentProductCacheEpoch else { return }

        URLCache.shared.removeAllCachedResponses()
        Task { await BondImageLoader.shared.reset() }

        let leftoverFragments = ["discovery", "dating", "admirer"]
        for key in defaults.dictionaryRepresentation().keys {
            let lower = key.lowercased()
            if leftoverFragments.contains(where: { lower.contains($0) }) {
                defaults.removeObject(forKey: key)
            }
        }

        persistAccount()
        defaults.set(SessionKey.currentProductCacheEpoch, forKey: SessionKey.productCacheEpoch)
    }
    func persistSession() {
        defaults.set(true, forKey: SessionKey.isSignedIn)
        defaults.set(email, forKey: SessionKey.email)
        persistAccount()
    }
}
