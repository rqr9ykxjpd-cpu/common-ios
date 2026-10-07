import Foundation
import Security

/// Kulüp hesabındayken yöneticinin kendi hesabı. "Ana hesaba geç" sunucuya
/// sormadan bu oturuma döner; kulüp hesabının oturumu yöneticinin hesabına
/// hiçbir zaman anahtar almaz.
///
/// Oturum (yenileme anahtarı dahil) Anahtar Zinciri'nde, yalnızca bu
/// cihazda: iCloud'a ve yedeğe gitmez.
struct MainAccount: Codable, Equatable {
    let userID: UUID
    let name: String
    let clubID: UUID
    let session: Data
}

enum MainAccountVault {
    private static let service = "com.campus.social.main-account"
    private static let account = "main"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() -> MainAccount? {
        var sorgu = query
        sorgu[kSecReturnData as String] = true
        sorgu[kSecMatchLimit as String] = kSecMatchLimitOne
        var sonuc: CFTypeRef?
        guard SecItemCopyMatching(sorgu as CFDictionary, &sonuc) == errSecSuccess,
              let data = sonuc as? Data else { return nil }
        return try? JSONDecoder().decode(MainAccount.self, from: data)
    }

    @discardableResult
    static func save(_ main: MainAccount) -> Bool {
        guard let data = try? JSONEncoder().encode(main) else { return false }
        SecItemDelete(query as CFDictionary)
        var ekle = query
        ekle[kSecValueData as String] = data
        ekle[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(ekle as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
