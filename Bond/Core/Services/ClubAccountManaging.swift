import Foundation

/// Kulüp hesapları: kulübün kendi açtığı hesabı Common hesabı kulübe bağlar
/// (sunucu: 20261007020000_club_accounts). Ayrı protokol (bkz. `PeopleSuggesting`).
protocol ClubAccountManaging: Sendable {
    /// Bu hesap hangi kulübün hesabı; değilse nil.
    func clubAccountClub(of userID: UUID) async throws -> UUID?
    /// Hesabı kulübün resmi hesabı yapar: adı kulübün adı, tikli, kulübü yönetir.
    /// Kulübün adını döner.
    func makeClubAccount(_ userID: UUID, clubID: UUID) async throws -> String
    /// Bağı, yöneticiliği, tiki ve muafiyeti kaldırır.
    func removeClubAccount(_ userID: UUID) async throws
}
