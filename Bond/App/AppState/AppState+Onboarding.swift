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

        // Sign in with Apple adı yalnızca ilk yetkilendirmede döndürür. Kullanıcıdan
        // Apple'ın zaten sağladığı bilgiyi yeniden istememek için görünen ad isteğe
        // bağlıdır; veritabanındaki zorunlu alanı kişisel olmayan bir varsayılanla
        // doldururuz. Kullanıcı bunu profilinden dilediği zaman değiştirebilir.
        let chosenName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Varsayılan ad yalnızca kaydedilen kopyaya yazılıyor. Taslağa yazınca kayıt
        // başarısız olup kullanıcı geri döndüğünde alanda "Common öğrencisi" kalıyordu.
        var kaydedilecek = draft
        if chosenName.isEmpty {
            kaydedilecek.name = L10n.Onboarding.defaultDisplayName
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
        startMessageListener()

        onboardingFailure = nil
        withAnimation(.smooth(duration: 0.55)) { route = .app }
        await startPushRegistration()
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
