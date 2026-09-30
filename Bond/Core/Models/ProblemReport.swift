import UIKit

/// "Sorun bildir" ile gelen bildirim. Kurucu ve moderatörler Ayarlar →
/// Şikâyetler → Sorunlar'da görüyor. İçerik şikâyetinden (`ModerationReport`)
/// ayrı: burada hedef bir kişi ya da içerik değil, uygulamanın kendisi.
struct ProblemReport: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let createdAt: Date
    var handledAt: Date?
    let reporterName: String?
    let reporterUsername: String?
    /// "1.0 (6) · iOS 26.0 · iPhone14,5 · Profil" gibi tek satır.
    let contextLine: String
    /// Destek yazışması: durum, yanıt sayısı, öğrencinin okunmamış yazısı.
    var status: SupportThread.Status = .open
    var replyCount: Int = 0
    var staffUnread: Bool = false
    var screen: String? = nil
    var reporterAvatarURL: URL? = nil

    var isOpen: Bool { handledAt == nil }
    /// Kapatılmış kayıt her zaman "çözüldü"; eski kayıtlarda durum alanı yok.
    var displayStatus: SupportThread.Status { isOpen ? (status == .resolved ? .open : status) : .resolved }

    var opening: SupportOpening {
        SupportOpening(id: id, message: message, createdAt: createdAt, screen: screen,
                       reporter: reporterUsername.map { "@\($0)" } ?? reporterName, status: displayStatus,
                       reporterAvatarURL: reporterAvatarURL)
    }
}

/// Bildirime otomatik eklenen bilgiler: sorunu yeniden üretebilmek için.
/// Kişisel veri yok; yalnızca sürüm, sistem, cihaz modeli ve ekran.
enum ProblemReportContext {
    @MainActor
    static func current(screen: String) -> [String: String] {
        let bundle = Bundle.main.infoDictionary
        let surum = bundle?["CFBundleShortVersionString"] as? String ?? "?"
        let derleme = bundle?["CFBundleVersion"] as? String ?? "?"
        return [
            "app": "\(surum) (\(derleme))",
            "ios": UIDevice.current.systemVersion,
            "device": deviceModel,
            "screen": screen,
            "locale": Locale.current.identifier,
        ]
    }

    /// Sunucudan gelen bilgileri moderasyon ekranı için tek satıra çevirir.
    static func line(from context: [String: String]) -> String {
        ["app", "ios", "device", "screen"]
            .compactMap { anahtar in
                guard let deger = context[anahtar], !deger.isEmpty else { return nil }
                return anahtar == "ios" ? "iOS \(deger)" : deger
            }
            .joined(separator: " · ")
    }

    private static var deviceModel: String {
        var bilgi = utsname()
        uname(&bilgi)
        return withUnsafeBytes(of: &bilgi.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

/// Sunucunun döndürdüğü hatalar (`report_problem`).
enum ProblemReportError: LocalizedError {
    case tooShort
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .tooShort: L10n.ProblemReport.tooShort
        case .rateLimited: L10n.ProblemReport.rateLimited
        }
    }

    static func from(_ error: Error) -> ProblemReportError? {
        let metin = String(describing: error) + error.localizedDescription
        if metin.contains("PROBLEM_REPORT_RATE_LIMIT") { return .rateLimited }
        if metin.contains("PROBLEM_REPORT_TOO_SHORT") { return .tooShort }
        return nil
    }
}
