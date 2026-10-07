import Foundation

/// Kulüp yöneticileri ve kulüp hesabına geçiş (sunucu:
/// 20261007020000_club_accounts, fonksiyon: club-account-switch).
/// Ayrı protokol (bkz. `PeopleSuggesting`).
protocol ClubAccountManaging: Sendable {
    /// Kişinin yöneticisi olduğu kulüpler (Common hesabının seçicisi).
    func managedClubs(of userID: UUID) async throws -> Set<UUID>
    /// Oturumdaki hesap bir kulübün hesabıysa kulübü ve `manager` hâlâ o
    /// kulübün yöneticisi mi; kulüp hesabı değilse nil.
    func clubAccountStatus(manager: UUID) async throws -> ClubAccountStatus?
    /// Oturumdaki hesabın oturumu, cihazda saklamak için (ana hesaba dönüş).
    func exportSession() -> Data?
    /// Kulübün hesabına geçer; oturum kulüp hesabının olur. Hesap yoksa açılır.
    func switchToClubAccount(_ clubID: UUID) async throws
    /// Kulüp hesabının bu cihazdaki oturumunu kapatır, saklanan oturuma döner.
    func returnToSession(_ stored: Data) async throws
    /// Açık kulüplerin hesapları: kulüp sayfası ↔ kulüp hesabı bağlantısı.
    func clubAccountLinks() async throws -> [ClubAccountLink]
    /// Kulüp hesabının kartı (kulüp sayfasından açmak için).
    func clubAccountProfile(_ profileID: UUID) async throws -> StudentProfile
}

struct ClubAccountLink: Equatable, Sendable {
    let clubID: UUID
    let profileID: UUID
    let username: String?
}

struct ClubAccountStatus: Equatable, Sendable {
    let clubID: UUID
    let managerOK: Bool
}

enum ClubAccountSwitchError: Error {
    /// Kişi artık bu kulübün yöneticisi değil.
    case notManager
    /// Ana hesabın saklanan oturumu geçersiz; yeniden giriş gerekiyor.
    case mainSessionLost
    case unavailable
}
