import Foundation

extension AppState {
    /// Kartın kendisi kararı verir: muaf ya da doğrulanmışsa görünmez.
    var eduNeedsAttention: Bool { eduStatus?.needsAttention ?? false }

    func loadEduStatus() async {
        do {
            eduStatus = try await service.fetchEduStatus()
            if eduDomains.isEmpty { eduDomains = (try? await service.fetchEduDomains()) ?? [] }
        } catch {
            guard !isCancellation(error) else { return }
            // Sessiz: kart bir sonraki açılışta gelir; hata banner'ı profil sekmesini kirletmesin.
        }
    }

    /// Bağlantıyı yeni adrese gönderir. Sunucu aynı adresi başka hesap kullandıysa
    /// reddeder (auth.users.email tekil).
    @discardableResult
    func requestEduVerification(_ rawEmail: String) async -> Bool {
        let adres = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard EduEmailCheck.isAllowed(adres, domains: eduDomains) else {
            showError(L10n.Edu.notAllowedDomain); return false
        }
        do {
            try await service.requestEduVerification(email: adres)
            if eduStatus == nil { eduStatus = .unknown }
            eduStatus?.pendingEmail = adres
            Haptics.success()
            return true
        } catch {
            let ham = (String(describing: error) + error.localizedDescription).lowercased()
            if ham.contains("already") || ham.contains("exists") || ham.contains("registered") {
                showError(L10n.Edu.alreadyUsed)
            } else if ham.contains("rate") || ham.contains("limit") {
                showError(L10n.Edu.rateLimited)
            } else {
                showError(error, fallback: L10n.Edu.sendFailed)
            }
            return false
        }
    }

    /// Bağlantı tıklandı mı? Uygulama öne gelince ve `bond://edu-verified` ile
    /// çağrılır; doğrulandıysa kutlama.
    @discardableResult
    func syncEduVerification(announce: Bool = true) async -> Bool {
        guard route == .app, eduStatus?.isPending == true || eduStatus == nil else { return false }
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
