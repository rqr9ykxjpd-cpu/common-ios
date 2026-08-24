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
    /// uygulamaya geçer. Aksi halde kullanıcı profilsiz şekilde içeri girer, keşif sebepsiz
    /// boş gelir ve durumun neden böyle olduğu anlaşılmaz.
    func finishOnboarding() async {
        guard !isFinishingOnboarding else { return }
        isFinishingOnboarding = true
        defer { isFinishingOnboarding = false }
        onboardingFailure = nil
        do {
            try await service.saveProfile(draft)
        } catch {
            let message = UserFacingError.message(error, fallback: L10n.Onboarding.saveFailed)
            onboardingFailure = message
            showError(message)
            return
        }

        // Fotoğraf zorunlu olduğu için yükleme hatası artık "sonra hallederiz" değil:
        // fotoğrafsız içeri alırsak zorunluluk kâğıt üstünde kalır. Kullanıcı bu ekranda
        // kalıp tekrar deniyor — profil sunucuya yazılmış olsa da yeniden kaydetmek
        // aynı satırı güncellediği için zararsız.
        guard let avatarData else {
            let message = L10n.Onboarding.needPhoto
            onboardingFailure = message
            showError(message)
            withAnimation(BondTheme.Motion.easing) { route = .onboarding(.photo) }
            return
        }
        do {
            avatarURL = try await service.updateAvatar(avatarData)
        } catch {
            let message = UserFacingError.message(error, fallback: L10n.Onboarding.photoUploadFailed)
            onboardingFailure = message
            showError(message)
            return
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
        startMessageListener()

        onboardingFailure = nil
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        await startPushRegistration()
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        show(name.isEmpty ? L10n.Auth.welcome : L10n.Auth.welcomeName(name))
    }

    func goBack(from step: OnboardingStep) {
        // İlk adımda gerçek oturum açıkken yalnızca Welcome ekranına dönmek,
        // arayüz ile kimlik durumunu birbirinden koparıyordu. İlk adımın çıkışı
        // OnboardingFlow'daki onaylı `signOut()` üzerinden yapılır.
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(BondTheme.Motion.easing) { route = .onboarding(previous) }
    }
}
