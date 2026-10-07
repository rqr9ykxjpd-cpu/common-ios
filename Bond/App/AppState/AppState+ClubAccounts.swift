import SwiftUI

/// Hesap geçişi sürerken ekranı örten perde: nereye geçildiği. Kulübe
/// geçerken kulüp, ana hesaba dönerken nil.
struct AccountSwitchCurtain: Equatable {
    let club: CampusClub?
    let logoURL: URL?
}

// MARK: - AppState+ClubAccounts
extension AppState {
    /// Kulübe yönetici atamak Common hesabının işi (sunucu kurucuya da izin veriyor).
    var canAssignClubManagers: Bool { currentUserID == OfficialAccount.id }

    /// Oturumdaki hesap bir kulübün hesabı: düzenleyicide bölüm/sınıf yok,
    /// satın alma ve hesap silme yok.
    var isClubAccount: Bool { mainAccount != nil || clubAccountClubID != nil }

    /// Profilde "Kulüp hesabına geç" çıkan kulüpler: yönettiklerim, açık olanlar.
    var clubSwitchTargets: [CampusClub] {
        guard !isClubAccount, service is any ClubAccountManaging else { return [] }
        return clubs.filter { managedClubIDs.contains($0.id) }
    }

    func managedClubs(of userID: UUID) async throws -> Set<UUID> {
        guard let masa = service as? any ClubAccountManaging else { return [] }
        return try await masa.managedClubs(of: userID)
    }

    /// Kulüp hesabındaysak hangi kulübün; ana hesabın yöneticiliği alındıysa
    /// ana hesaba döner. Sessiz: sunucu eskiyse ya da ağ yoksa dokunmaz.
    func loadClubAccountStatus() async {
        guard let masa = service as? any ClubAccountManaging else { return }
        let yonetici = mainAccount?.userID ?? currentUserID
        let durum: ClubAccountStatus?
        do { durum = try await masa.clubAccountStatus(manager: yonetici) } catch { return }
        guard let durum else {
            // Oturum kulüp hesabı değil; kayıt duruyorsa geçiş yarıda kalmış.
            clubAccountClubID = nil
            if mainAccount != nil {
                MainAccountVault.clear()
                mainAccount = nil
            }
            return
        }
        clubAccountClubID = durum.clubID
        if mainAccount != nil, !durum.managerOK {
            await switchToMainAccount(notice: L10n.ClubSwitch.noLongerManager)
        }
    }

    /// Yöneticinin oturumu cihazda saklanır, kulübün hesabına geçilir. Hesap
    /// yoksa sunucu açar; kulübün adı, logosu ve tikiyle gelir.
    func switchToClubAccount(_ club: CampusClub) async {
        guard !isAccountActionInProgress, mainAccount == nil,
              let masa = service as? any ClubAccountManaging,
              let oturum = masa.exportSession() else { return }
        let ana = MainAccount(userID: currentUserID, name: draft.name, clubID: club.id, session: oturum)
        guard MainAccountVault.save(ana) else {
            showError(L10n.ClubSwitch.failed)
            return
        }
        isAccountActionInProgress = true
        withAnimation(.smooth(duration: 0.3)) {
            accountSwitch = AccountSwitchCurtain(club: club, logoURL: clubExtras[club.id]?.logoURL)
        }
        persistAccount()
        await (service as? any PresenceReporting)?.markOffline()
        await unregisterPushToken()
        do {
            try await masa.switchToClubAccount(club.id)
        } catch {
            MainAccountVault.clear()
            isAccountActionInProgress = false
            withAnimation(.smooth(duration: 0.3)) { accountSwitch = nil }
            await startPushRegistration()
            showError(error as? ClubAccountSwitchError == .notManager ? L10n.ClubSwitch.notManager : L10n.ClubSwitch.failed)
            return
        }
        mainAccount = ana
        await enterSwitchedAccount(notice: L10n.ClubSwitch.switched(club.name))
    }

    /// Kulüp hesabının bu cihazdaki oturumu kapanır, yöneticinin saklanan
    /// oturumuna dönülür. O oturum da bittiyse giriş ekranı.
    func switchToMainAccount(notice: String? = nil) async {
        guard !isAccountActionInProgress, let ana = mainAccount,
              let masa = service as? any ClubAccountManaging else { return }
        isAccountActionInProgress = true
        withAnimation(.smooth(duration: 0.3)) {
            accountSwitch = AccountSwitchCurtain(club: nil, logoURL: nil)
        }
        persistAccount()
        await (service as? any PresenceReporting)?.markOffline()
        await unregisterPushToken()
        do {
            try await masa.returnToSession(ana.session)
        } catch {
            isAccountActionInProgress = false
            withAnimation(.smooth(duration: 0.3)) { accountSwitch = nil }
            await BondImageLoader.shared.reset()
            try? await service.signOut()
            clearSession(keepAccountData: true)
            showError(L10n.ClubSwitch.mainSessionLost)
            return
        }
        MainAccountVault.clear()
        mainAccount = nil
        await enterSwitchedAccount(notice: notice ?? L10n.ClubSwitch.backToMain)
    }

    /// Oturum değişti: ekran verisi boşalır, yeni hesap girişteki gibi yüklenir.
    private func enterSwitchedAccount(notice: String) async {
        await BondImageLoader.shared.reset()
        resetSessionState()
        // Gizli mod yerelde de tutuluyor; bir hesabın tercihi öbürüne yazılmasın.
        ghostMode = false
        _ = await completeSocialSignIn()
        isAccountActionInProgress = false
        withAnimation(.smooth(duration: 0.35)) { accountSwitch = nil }
        show(notice)
        // Akış ve Sohbet sekmeleri verilerini ilk açılışta bir kez yüklüyor;
        // yeni hesabınkiler burada gelir.
        async let akis: Void = loadFeed()
        async let sohbetler: Void = loadConversations()
        async let oneriler: Void = loadSuggestions()
        _ = await (akis, sohbetler, oneriler)
    }
}
