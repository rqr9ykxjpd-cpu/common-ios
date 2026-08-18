import Foundation

/// Ekranın üstünde beliren kısa mesaj. Daha önce düz `String` idi ve görünüm her
/// mesajı yeşil tikle gösteriyordu — hata mesajlarının başında da onay işareti
/// çıkıyordu, bu da hatayı başarı gibi okutuyordu.
struct AppToastMessage: Equatable {
    enum Kind { case info, error }

    let text: String
    let kind: Kind

    var systemImage: String {
        switch kind {
        case .info: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

/// Kullanıcıya gösterilecek hata metnini üretir.
///
/// Daha önce her yerde doğrudan `error.localizedDescription` gösteriliyordu. Bu,
/// kullanıcının karşısına sunucunun ya da SDK'nın iç diliyle yazılmış cümleler
/// çıkarıyordu — "nonces mismatch", "provider is not enabled", "PGRST205",
/// "new row violates row-level security policy". Bunlar kullanıcıya hiçbir şey
/// anlatmadığı gibi uygulamanın yarım kalmış hissi vermesine yol açıyor.
///
/// Burada bilinen hatalar Türkçe ve eyleme dönük mesajlara çevriliyor; tanınmayan
/// her şey çağıran tarafın verdiği bağlam cümlesine düşüyor. Ham hata hiçbir
/// durumda kullanıcıya gösterilmiyor, ama DEBUG'da konsola yazılıyor ki
/// geliştirirken kaybolmasın.
enum UserFacingError {

    /// - Parameters:
    ///   - error: Yakalanan hata.
    ///   - fallback: Tanınmayan hatalarda gösterilecek, o işleme özgü cümle.
    ///     Örnek: "Gönderi paylaşılamadı." Sonuna "Tekrar dene." gibi bir yönlendirme
    ///     eklemek gerekmiyor, burada ekleniyor.
    static func message(_ error: Error, fallback: String) -> String {
#if DEBUG
        print("[Campus] ham hata: \(error)")
#endif
        if let known = known(error) { return known }
        return fallback
    }

    private static func known(_ error: Error) -> String? {
        // Kendi tanımladığımız hatalar zaten Türkçe ve yerinde.
        if let backendError = error as? BackendServiceError {
            return backendError.errorDescription
        }
        if let connection = connectionMessage(error) { return connection }
        return contentMessage(String(describing: error).lowercased())
    }

    /// Ağ katmanı. Bunlar en sık görülen hatalar ve çözümü kullanıcıda.
    private static func connectionMessage(_ error: Error) -> String? {
        let urlError: URLError?
        if let direct = error as? URLError {
            urlError = direct
        } else {
            urlError = (error as NSError).underlyingErrors.compactMap { $0 as? URLError }.first
        }
        guard let code = urlError?.code else { return nil }
        switch code {
        case .notConnectedToInternet:
            return "İnternet bağlantın yok gibi görünüyor."
        case .timedOut:
            return "Bağlantı zaman aşımına uğradı. Tekrar dene."
        case .networkConnectionLost:
            return "Bağlantı koptu. Tekrar dene."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "Sunucuya ulaşılamıyor. Birazdan tekrar dene."
        case .dataNotAllowed:
            return "Mobil veri kapalı görünüyor."
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "Güvenli bağlantı kurulamadı. Ağını kontrol et."
        default:
            return nil
        }
    }

    /// Sunucudan ve kimlik doğrulama SDK'sından gelen metinler. Supabase bunları
    /// yapılandırılmış kod yerine düz cümle olarak döndürdüğü için içerikten tanıyoruz.
    private static func contentMessage(_ text: String) -> String? {
        for (needles, message) in table where needles.allSatisfy({ text.contains($0) }) {
            return message
        }
        return nil
    }

    /// Sıra önemli: daha özel kalıplar üstte. Her satır "bu parçaların hepsi geçiyorsa"
    /// biçiminde okunur.
    private static let table: [([String], String)] = [
        // — Giriş —
        (["nonce"], "Giriş doğrulaması tamamlanamadı. Lütfen tekrar dene."),
        (["provider is not enabled"], "Bu giriş yöntemi şu anda kullanılamıyor. Diğer seçeneği dene."),
        (["bad_oauth_state"], "Giriş yarıda kaldı. Baştan dene."),
        (["invalid", "token"], "Giriş bilgisi doğrulanamadı. Tekrar dene."),
        (["email", "already"], "Bu e-posta başka bir hesapta kayıtlı."),
        (["banned"], "Bu hesap askıya alınmış."),
        (["signup", "disabled"], "Yeni kayıtlar şu anda kapalı."),
        (["rate limit"], "Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene."),
        (["over_email_send_rate_limit"], "Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene."),

        // — Oturum —
        (["authentication required"], "Oturumun sona ermiş. Tekrar giriş yap."),
        (["jwt expired"], "Oturumun sona ermiş. Tekrar giriş yap."),
        (["missing session"], "Oturumun sona ermiş. Tekrar giriş yap."),

        // — Profil kuralları (save_my_profile içindeki kontroller) —
        (["at least three interests"], "En az 3 ilgi alanı seçmelisin."),
        (["exactly three prompts"], "Üç profil sorusunun da cevaplanması gerekiyor."),
        (["prompt answers cannot be empty"], "Profil sorularını boş bırakamazsın."),

        // — Yetki ve veri —
        (["row-level security"], "Bunu yapma yetkin yok."),
        (["permission denied"], "Bunu yapma yetkin yok."),
        (["duplicate key"], "Bu kayıt zaten var."),
        (["violates foreign key"], "İşlem tamamlanamadı: ilgili kayıt bulunamadı."),
        (["value too long"], "Girdiğin metin çok uzun."),

        // — Sunucu kurulumu eksik. Kullanıcıya "sen yanlış yaptın" dedirtmemek önemli. —
        (["pgrst205"], "Bu özellik sunucuda henüz hazır değil."),
        (["pgrst202"], "Bu özellik sunucuda henüz hazır değil."),
        (["schema cache"], "Bu özellik sunucuda henüz hazır değil."),

        // — Dosya yükleme —
        (["payload too large"], "Dosya çok büyük. Daha küçük bir fotoğraf dene."),
        (["exceeded the maximum allowed size"], "Fotoğraf çok büyük. Başka bir tane dene."),
        (["bucket not found"], "Fotoğraf alanı sunucuda bulunamadı."),

        // — Genel sunucu —
        (["503"], "Sunucu şu anda yanıt vermiyor. Birazdan tekrar dene."),
        (["timeout"], "İşlem zaman aşımına uğradı. Tekrar dene.")
    ]
}
