import Foundation

/// Kullanıcı adı (@cem.budak) kuralları. Sunucudaki `username_is_valid` ile
/// birebir aynı (bkz. 20260926010000_usernames.sql); sunucu yine de son sözü
/// söylüyor, burada yalnızca anında geri bildirim için.
///
/// Neden kullanıcı adı: Apple ile girişten sonra gerçek adı tekrar istemek
/// App Review Guideline 4'e takılıyor (21 Eylül reddi). Apple adı yalnızca ilk
/// yetkilendirmede veriyor; zorunlu bir ad alanı ikinci girişte boş kalıyordu.
/// Kullanıcı adı Apple'ın verdiği bir bilgi değil, uygulamaya özel.
enum Username {
    static let minLength = 3
    static let maxLength = 20

    private static let reserved: Set<String> = [
        "common", "admin", "administrator", "moderator", "mod", "support",
        "destek", "apple", "google", "root", "system", "yonetici", "kurucu",
        "founder", "official", "resmi", "help", "yardim", "null", "undefined",
    ]

    /// Yazılanı kurala yaklaştırır: küçük harf, Türkçe harfler Latin, izinsiz
    /// karakterler atılır. Yazarken çağrılıyor; nokta ve alt çizgi korunur.
    static func normalize(_ raw: String) -> String {
        let latin = raw
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "ı")
            .lowercased()
            .map { char -> String in
                switch char {
                case "ç": "c"
                case "ğ": "g"
                case "ı": "i"
                case "ö": "o"
                case "ş": "s"
                case "ü": "u"
                case "â": "a"
                case "î": "i"
                case "û": "u"
                default: String(char)
                }
            }
            .joined()
        let izinli = latin.unicodeScalars.filter {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "." || $0 == "_"
        }
        return String(String.UnicodeScalarView(izinli).prefix(maxLength))
    }

    static func isValid(_ candidate: String) -> Bool {
        guard (minLength...maxLength).contains(candidate.count),
              candidate == normalize(candidate),
              !candidate.hasPrefix("."), !candidate.hasSuffix("."),
              !candidate.contains(".."),
              !reserved.contains(candidate) else { return false }
        return (try? ContentSafety.validate(candidate)) != nil
    }

    /// Kayıt ekranındaki öneri: sağlayıcı ad verdiyse ondan (Cem Budak →
    /// cem.budak), vermediyse "ogrenci" ve dört rakam. Alınmışsa sunucu reddeder,
    /// kullanıcı değiştirir.
    static func suggestion(from name: String) -> String {
        let parcalar = name.split(whereSeparator: { $0.isWhitespace })
            .map { normalize(String($0)).replacingOccurrences(of: ".", with: "") }
            .filter { !$0.isEmpty }
        var aday = String(parcalar.prefix(2).joined(separator: ".").prefix(14))
        while aday.hasSuffix(".") { aday.removeLast() }
        if isValid(aday) { return aday }
        return "ogrenci\(Int.random(in: 1000...9999))"
    }
}

/// Kullanıcı adı alınırken sunucunun döndürdüğü hatalar.
enum UsernameError: LocalizedError, Equatable {
    case invalid
    case taken

    var errorDescription: String? {
        switch self {
        case .invalid: L10n.Username.invalid
        case .taken: L10n.Username.taken
        }
    }

    /// PostgREST hata metninden: `claim_my_username` USERNAME_INVALID /
    /// USERNAME_TAKEN diye yükseltiyor.
    static func from(_ error: Error) -> UsernameError? {
        let metin = String(describing: error) + error.localizedDescription
        if metin.contains("USERNAME_TAKEN") { return .taken }
        if metin.contains("USERNAME_INVALID") { return .invalid }
        return nil
    }
}
