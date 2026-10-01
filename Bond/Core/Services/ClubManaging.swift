import Foundation

/// Kulüp yönetimi (1.2). Ayrı protokol: `ProductService`e eklenseydi her
/// uygulamasına (örnek, yapılandırılmamış) boş gövde gerekiyordu.
protocol ClubManaging: Sendable {
    /// Logo ve iletişim; kulüp kimliğine göre.
    func fetchClubExtras() async throws -> [UUID: ClubExtras]
    /// Yönetici olarak atandığım kulüpler (kurucu hepsini yönetir).
    func fetchManagedClubIDs() async throws -> Set<UUID>
    /// Kurucu: kapalılar dahil bütün kulüpler.
    func fetchAdminClubs() async throws -> [ClubAdminEntry]
    /// Yeni kulüp (kurucu) ya da düzenleme (kurucu/yönetici). Kulüp kimliğini döner.
    func saveClub(_ draft: ClubDraft) async throws -> UUID
    /// Logoyu yükler ve kulübe bağlar; yeni adresi döner.
    func uploadClubLogo(_ clubID: UUID, imageData: Data) async throws -> URL?
    func fetchClubPeople(_ clubID: UUID) async throws -> [ClubPerson]
    /// Kurucu: yönetici ata / kaldır.
    func setClubManager(_ clubID: UUID, userID: UUID, enabled: Bool) async throws -> Bool
    func removeClubMember(_ clubID: UUID, userID: UUID) async throws
}
