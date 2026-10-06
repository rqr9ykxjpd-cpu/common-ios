import Foundation

/// Görünen ad gerçek ad: Apple ya da Google'dan gelir ve değiştirilemez.
/// Sağlayıcı ad vermediyse görünen ad kullanıcı adıdır; kişi gerçek adını bir
/// kez yazabilir. Asıl kural sunucuda (`profiles_name_lock`, NAME_LOCKED);
/// burası yalnızca alanı açık mı kilitli mi göstermek için aynı ölçüt.
enum NameLock {
    static func isEditable(name: String, username: String, userID: UUID, isFounder: Bool) -> Bool {
        if isFounder { return true }
        if userID == OfficialAccount.id { return false }
        let ad = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty else { return true }
        let kullaniciAdiGibi = ad.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "_"
        }
        return kullaniciAdiGibi || ad.lowercased() == username.lowercased()
    }
}
