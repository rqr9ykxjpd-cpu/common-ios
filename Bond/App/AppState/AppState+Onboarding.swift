import SwiftUI

// MARK: - AppState+Onboarding
extension AppState {
    func advance(from step: OnboardingStep) {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            Task { await finishOnboarding() }
            return
        }
        withAnimation(BondTheme.Motion.easing) { route = .onboarding(next) }
    }

    /// Onboarding'in son adımı. Profili sunucuya kaydeder ve **yalnızca kayıt başarılıysa**
    /// uygulamaya geçer. Aksi halde kullanıcı profilsiz şekilde içeri girer, İnsanlar
    /// listesi sebepsiz boş gelir ve durumun neden böyle olduğu anlaşılmaz.
    func finishOnboarding() async {
        guard !isFinishingOnboarding else { return }
        isFinishingOnboarding = true
        defer { isFinishingOnboarding = false }
        onboardingFailure = nil

        // Gerçek ad kayıtta sorulmuyor (Guideline 4: Apple ile girişten sonra adı
        // tekrar isteme). Sağlayıcı ad verdiyse o görünür; vermediyse görünen ad
        // olarak kullanıcı adı. Kullanıcı ikisini de profilinden değiştirebilir.
        let chosenName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Yalnızca kaydedilen kopyaya yazılıyor; kayıt başarısız olursa taslak
        // değişmemiş kalıyor.
        var kaydedilecek = draft
        if chosenName.isEmpty {
            kaydedilecek.name = draft.username
        }
        do {
            try await service.saveProfile(kaydedilecek)
        } catch {
            let message = UserFacingError.message(error, fallback: L10n.Onboarding.saveFailed)
            onboardingFailure = message
            showError(message)
            return
        }
        draft.name = kaydedilecek.name

        // Kullanıcı adı profil satırı açıldıktan sonra alınabiliyor. Kayıt ekranında
        // "uygun" görünse de arada başkası almış olabilir; o zaman o ekrana dönülür.
        do {
            try await service.claimUsername(draft.username)
        } catch {
            let message = (error as? UsernameError)?.errorDescription
                ?? UserFacingError.message(error, fallback: L10n.Onboarding.saveFailed)
            onboardingFailure = message
            showError(message)
            if error is UsernameError {
                withAnimation(BondTheme.Motion.easing) { route = .onboarding(.identity) }
            }
            return
        }

        // Profil fotoğrafı isteğe bağlıdır. Kullanıcı bir fotoğraf seçtiyse yüklemeyi
        // deneriz; yükleme başarısız olduğunda kayıt akışını kilitlemeyiz. Yerel veriyi
        // temizleyip kullanıcıya profilinden daha sonra tekrar deneyebileceğini bildiren
        // hata mesajını gösteririz.
        if let avatarData {
            do {
                avatarURL = try await service.updateAvatar(avatarData)
            } catch {
                self.avatarData = nil
                let message = UserFacingError.message(error, fallback: L10n.Onboarding.photoUploadFailed)
                showError(message)
            }
        }

        persistSession()
        // Kayıt akışıyla giren kullanıcı da anlık mesajları almalı; bunlar yalnızca `signIn` ve
        // `restoreBackendSession` içinde kuruluyordu, yeni kullanıcı uygulamayı yeniden
        // başlatana kadar gelen mesajları görmüyordu.
        await loadMyProfilePhotos()
        await loadNotifications()
        await loadPlaces(silently: true)
        await loadStories()
        await loadClubs(silently: true)
        await loadMeetingRequests()
        await loadMessageRequests(silently: true)
        try? await service.touchLastActive()
        startPresenceHeartbeat()
        startMessageListener()

        onboardingFailure = nil
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        await startPushRegistration()
        // Yeni öğrenci: kayıt biter bitmez "Kampüse son bir adım". Geçebilir;
        // o zaman gezinti modunda kalır, kilitli bir şeye dokununca pencere yine açılır.
        await loadEduStatus()
        if isEduLocked {
            try? await Task.sleep(for: .seconds(0.9))
            presentEduGate(.welcome)
        }
        show(chosenName.isEmpty ? L10n.Auth.welcome : L10n.Auth.welcomeName(chosenName))
    }

    func goBack(from step: OnboardingStep) {
        // İlk adımda gerçek oturum açıkken yalnızca Welcome ekranına dönmek,
        // arayüz ile kimlik durumunu birbirinden koparıyordu. İlk adımın çıkışı
        // OnboardingFlow'daki onaylı `signOut()` üzerinden yapılır.
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(BondTheme.Motion.easing) { route = .onboarding(previous) }
    }
}
