import Foundation

extension AppState {
    /// Kartın kendisi kararı verir: muaf ya da doğrulanmışsa görünmez.
    var eduNeedsAttention: Bool {
        EduVerificationRollout.isEnabled && (eduStatus?.needsAttention ?? false)
    }

    func loadEduStatus() async {
        guard EduVerificationRollout.isEnabled else { return }
        do {
            eduStatus = try await service.fetchEduStatus()
            if eduStatus?.isVerified == true, myBadge == .none {
                // Sunucu doğrulama sırasında aynı rozeti profile de yazar. Yerel
                // durum hemen güncellensin; yeniden giriş beklemeyelim.
                myBadge = .verified
                draft.badge = .verified
                persistAccount()
            }
            if eduDomains.isEmpty { _ = await loadEduDomains() }
        } catch {
            guard !isCancellation(error) else { return }
            // Sessiz: kart bir sonraki açılışta gelir; hata banner'ı profil sekmesini kirletmesin.
        }
    }

    /// İzinli alan adları sunucudan gelir. Liste yokken doğrulama isteğini
    /// göndermiyoruz; aksi halde Auth hesabının e-postası desteklenmeyen bir
    /// adresle değişebilir ama kullanıcı hiçbir zaman rozet alamaz.
    @discardableResult
    func loadEduDomains() async -> Bool {
        do {
            let domains = try await service.fetchEduDomains()
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            guard !domains.isEmpty else { return false }
            eduDomains = Array(Set(domains)).sorted()
            return true
        } catch {
            guard !isCancellation(error) else { return false }
            return false
        }
    }

    /// Bağlantıyı yeni adrese gönderir. Sunucu aynı adresi başka hesap kullandıysa
    /// reddeder (auth.users.email tekil).
    @discardableResult
    func requestEduVerification(_ rawEmail: String) async -> Bool {
        let adres = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if eduDomains.isEmpty, !(await loadEduDomains()) {
            showError(L10n.Edu.domainsUnavailable); return false
        }
        if !EduEmailCheck.isAllowed(adres, domains: eduDomains) {
            showError(L10n.Edu.notAllowedDomain); return false
        }
        do {
            try await service.requestEduVerification(email: adres)
            lastEduErrorCode = nil
            if eduStatus == nil { eduStatus = .unknown }
            eduStatus?.pendingEmail = adres
            Haptics.success()
            return true
        } catch {
            let ham = (String(describing: error) + error.localizedDescription).lowercased()
            // Kısa, kişisel veri içermeyen kod: öğrenci "Sorun bildir"e basarsa
            // talebe eklenir, destek neyin takıldığını tahmin etmek zorunda kalmaz.
            if ham.contains("already") || ham.contains("exists") || ham.contains("registered") {
                lastEduErrorCode = "email_exists"
                showError(L10n.Edu.alreadyUsed)
            } else if ham.contains("rate") || ham.contains("limit") {
                lastEduErrorCode = "rate_limit"
                showError(L10n.Edu.rateLimited)
            } else {
                lastEduErrorCode = "send_failed"
                showError(error, fallback: L10n.Edu.sendFailed)
            }
            return false
        }
    }

    /// Bağlantı tıklandı mı? Uygulama öne gelince ve `bond://edu-verified` ile
    /// çağrılır; doğrulandıysa kutlama.
    @discardableResult
    func syncEduVerification(announce: Bool = true) async -> Bool {
        guard EduVerificationRollout.isEnabled, route == .app,
              eduStatus?.isPending == true || eduStatus == nil else { return false }
        let oldu = (try? await service.syncEduVerification()) ?? false
        if oldu {
            await loadEduStatus()
            if announce, eduStatus?.isVerified == true {
                show(L10n.Edu.verifiedToast)
                Haptics.success()
            }
        }
        return oldu
    }
}
