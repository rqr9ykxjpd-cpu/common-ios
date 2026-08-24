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
        let friendly = known(error) ?? fallback
#if DEBUG
        // Geliştirme derlemesinde ham hata ekrana da yazılıyor. Konsoldan satır
        // aratmak her hata turunda ayrı bir gidiş geliş demekti; artık ekran
        // görüntüsü tek başına yeterli. Release'de bu blok yok.
        print("[Bond] ham hata: \(error)")
        DebugErrorLog.append(error, context: fallback)
        return friendly + "\n⟨" + String(describing: error).prefix(160) + "⟩"
#else
        return friendly
#endif
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
            return L10n.Errors.offline
        case .timedOut:
            return L10n.Errors.timedOut
        case .networkConnectionLost:
            return L10n.Errors.connectionLost
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return L10n.Errors.hostUnreachable
        case .dataNotAllowed:
            return L10n.Errors.dataNotAllowed
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return L10n.Errors.secureFailed
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
        // Sunucunun jetonu üreten servisiyle isteği doğrulayan servisin saatleri
        // ayrıştığında çıkıyor. Kullanıcının yapabileceği bir şey yok ve kısa
        // sürede kendiliğinden geçiyor; `AppState` zaten bir kez sessizce yeniden
        // deniyor, bu metin ancak o da tutmazsa görünüyor.
        (["pgrst303"], L10n.Errors.clockSkew),

        // — Giriş —
        (["nonce"], L10n.Errors.nonce),
        (["provider is not enabled"], L10n.Errors.providerDisabled),
        (["bad_oauth_state"], L10n.Errors.oauthState),
        (["invalid", "token"], L10n.Errors.invalidToken),
        (["email", "already"], L10n.Errors.emailTaken),
        (["banned"], L10n.Errors.banned),
        (["signup", "disabled"], L10n.Errors.signupDisabled),
        (["rate limit"], L10n.Errors.rateLimit),
        (["over_email_send_rate_limit"], L10n.Errors.rateLimit),

        // — Oturum —
        (["authentication required"], L10n.Errors.sessionExpired),
        (["jwt expired"], L10n.Errors.sessionExpired),
        (["missing session"], L10n.Errors.sessionExpired),

        // — Profil kuralları (save_my_profile içindeki kontroller) —
        (["at least three interests"], L10n.Errors.minInterests),
        (["post_limit"], L10n.Composer.postLimit(CampusLimits.maxPostsPerUser)),
        (["quota_post"], L10n.Composer.postLimit(CampusLimits.maxPostsPerUser)),

        // — Yetki ve veri —
        (["row-level security"], L10n.Errors.permission),
        (["permission denied"], L10n.Errors.permission),
        (["duplicate key"], L10n.Errors.duplicate),
        (["violates foreign key"], L10n.Errors.foreignKey),
        (["value too long"], L10n.Errors.tooLong),

        // — Sunucu kurulumu eksik ya da uygulama sunucudan yeni. —
        //
        // Bunu gören kişi öğrenci; ne migration çalıştırabilir ne de sorun onda.
        // "Hazır değil" demek onu çıkmaza sokuyordu: ne yapacağını bilmiyor, kendi
        // hatası sanıyor. Sorunun bizde olduğunu söyleyip suçu üstleniyoruz.
        // Geliştiricinin ihtiyacı olan ham hata zaten DEBUG'da konsola yazılıyor.
        (["pgrst205"], L10n.Errors.serverGap),
        (["pgrst202"], L10n.Errors.serverGap),
        (["schema cache"], L10n.Errors.serverGap),

        // — Dosya yükleme —
        (["payload too large"], L10n.Errors.fileTooLarge),
        (["exceeded the maximum allowed size"], L10n.Errors.photoTooLarge),
        (["bucket not found"], L10n.Errors.bucketMissing),

        // — Genel sunucu —
        (["503"], L10n.Errors.unavailable),
        (["timeout"], L10n.Errors.timeout)
    ]
}

#if DEBUG
/// Hataları cihazdaki bir dosyaya yazar.
///
/// `print` çıktısı yalnızca hata ayıklayıcıya gidiyor; cihaz bağlıyken bile
/// dışarıdan okunamıyor (`log collect` root istiyor, `devicectl --console`
/// uygulamanın stdout'unu iletmiyor). Dosya ise `devicectl device copy` ile
/// çekilebiliyor — böylece telefonda oluşan bir hatanın tam metnine, kullanıcıdan
/// ekran görüntüsü istemeden ulaşılabiliyor.
///
/// Yalnızca geliştirme derlemesinde; App Store sürümünde bu tip hiç derlenmiyor.
enum DebugErrorLog {
    private static let queue = DispatchQueue(label: "campus.debug.errorlog")

    static var fileURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("hatalar.log")
    }

    static func append(_ error: Error, context: String) {
        guard let fileURL else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(context)\n\(error)\n\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
#endif
