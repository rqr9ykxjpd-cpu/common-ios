#if DEBUG
import Foundation
import UIKit

/// Örnek modda kulüp yöneticileri ve hesap geçişi bu açılış boyunca bellekte.
/// Geçişte oturum kulübün örnek hesabına döner (bkz. `SampleAccountSwitch`).
extension SampleProductService: ClubAccountManaging {
    func managedClubs(of userID: UUID) async throws -> Set<UUID> {
        await SampleClubManagerStore.shared.clubs[userID] ?? []
    }

    func clubAccountStatus(manager: UUID) async throws -> ClubAccountStatus? {
        SampleAccountSwitch.clubID.map { ClubAccountStatus(clubID: $0, managerOK: true) }
    }

    func exportSession() -> Data? { Data("ornek-oturum".utf8) }

    func switchToClubAccount(_ clubID: UUID) async throws {
        guard let kulup = try await fetchClubs().clubs.first(where: { $0.id == clubID }) else {
            throw ClubAccountSwitchError.notManager
        }
        try await Task.sleep(for: .milliseconds(700))
        SampleAccountSwitch.enter(clubID: clubID, name: kulup.name)
    }

    func returnToSession(_ stored: Data) async throws {
        try await Task.sleep(for: .milliseconds(500))
        SampleAccountSwitch.leave()
    }

    /// Örnekte ilk kulübün hesabı açılmış sayılır.
    func clubAccountLinks() async throws -> [ClubAccountLink] {
        guard let ilk = try await fetchClubs().clubs.first else { return [] }
        return [ClubAccountLink(clubID: ilk.id, profileID: SampleAccountSwitch.accountID(for: ilk.id), username: "fotograf.toplu")]
    }

    func clubAccountProfile(_ profileID: UUID) async throws -> StudentProfile {
        guard let kulup = try await fetchClubs().clubs.first(where: { SampleAccountSwitch.accountID(for: $0.id) == profileID }) else {
            throw BackendServiceError.missingSession
        }
        let taslak = SampleData.clubAccountDraft(kulup.name)
        return StudentProfile(
            id: profileID, name: taslak.name, age: 18, university: taslak.university,
            department: taslak.department, year: taslak.year, bio: kulup.summary, interests: [],
            imageURL: nil, isVerified: true, badge: .verified
        )
    }
}

/// Common'un seçicisi: kim hangi kulübü yönetiyor.
actor SampleClubManagerStore {
    static let shared = SampleClubManagerStore()
    private(set) var clubs: [UUID: Set<UUID>] = [:]
    func set(_ user: UUID, _ club: UUID, _ enabled: Bool) {
        var kume = clubs[user] ?? []
        if enabled { kume.insert(club) } else { kume.remove(club) }
        clubs[user] = kume
    }
}

/// Örnek modda oturumdaki hesap: kulübe geçilince kulübün örnek hesabı.
enum SampleAccountSwitch {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var active: (clubID: UUID, name: String)?
    /// Kulüp hesabının sabit kimliği; her kulüp için aynı kalsın diye kulüpten türetilir.
    static func accountID(for clubID: UUID) -> UUID {
        var bytes = clubID.uuid
        bytes.0 ^= 0xC1
        return UUID(uuid: bytes)
    }

    static var clubID: UUID? { lock.withLock { active?.clubID } }
    static var clubName: String? { lock.withLock { active?.name } }
    static var accountID: UUID? { clubID.map(accountID(for:)) }

    static func enter(clubID: UUID, name: String) { lock.withLock { active = (clubID, name) } }
    static func leave() { lock.withLock { active = nil } }

    /// "Ben"in fotoğrafı örnekte yalnızca uygulama varlığı; açılışta belleğe
    /// yükleniyor ve hesap geçişinde siliniyor. Ana hesaba dönünce de görünsün
    /// diye bir kez dosyaya yazılıp adresi veriliyor.
    static let mainAvatarFileURL: URL? = {
        guard let asset = SampleData.me.imageAssetName,
              let data = UIImage(named: asset)?.jpegData(compressionQuality: 0.85) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ornek-ben.jpg")
        return (try? data.write(to: url)) != nil ? url : nil
    }()
}
#endif
