import Foundation
import Supabase

final class SupabaseProductService: ProductService, @unchecked Sendable {
    let client: SupabaseClient
    static let postgresDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var currentUserID: UUID? { client.auth.currentUser?.id }
    var currentUserEmail: String? { client.auth.currentUser?.email }

    init(configuration: BackendConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(decoder: Self.decoder),
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    /// Sunucudan gelen tarihleri çözer.
    ///
    /// Varsayılan çözücü yalnızca zaman damgası bekliyor. `profiles.birth_date` ise
    /// Postgres'te `date` tipinde ve saatsiz geliyor ("2003-10-18"), bu yüzden
    /// çözümleme "Invalid date format" ile patlıyordu.
    ///
    /// Bu tek alan beş ayrı yapıda okunuyor — kendi profilim, keşif adayları,
    /// yerdeki kişiler, ziyaretçiler, sohbet ve gönderi yazarları. Yani hata
    /// girişten Tanış'a kadar her şeyi kırıyordu; gerçek veri olmadığı için
    /// bugüne kadar ortaya çıkmamıştı.
    /// `ISO8601DateFormatter` Sendable değil; okuma amaçlı paylaşımı güvenli olduğu
    /// için tip düzeyinde tutuluyor. Her tarih için yeniden kurmak yüz gönderilik bir
    /// akışta gereksiz maliyet olurdu.
    nonisolated(unsafe) private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = isoWithFraction.date(from: raw) { return date }
            if let date = isoWithoutFraction.date(from: raw) { return date }
            if let date = postgresDateFormatter.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Tanınmayan tarih biçimi: \(raw)"
                )
            )
        }
        return decoder
    }()
}

