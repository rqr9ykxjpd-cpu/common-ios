import Foundation

/// Abonelik kademesi ve her kademenin sınırları.
///
/// Sıralı: `pro` her şeyi kapsar. Karşılaştırma `rawValue` üzerinden yapılıyor,
/// böylece "Plus ve üstü" demek tek satır.
///
/// Buradaki sayılar arayüzde göstermek ve erken uyarmak için. **Asıl sınır
/// sunucuda uygulanmak zorunda**: istemcideki bir sayaç, uygulamayı kurcalayan
/// biri için hiçbir engel değil.
enum SubscriptionTier: Int, Comparable, Codable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .free: "Ücretsiz"
        case .plus: "Plus"
        case .pro: "Pro"
        }
    }

    // MARK: - Sayılı sınırlar (nil = sınırsız)

    /// Tanış'ta 2 günde kullanılabilecek beğeni.
    var likeQuota: Int? {
        switch self {
        case .free: 5
        case .plus: 10
        case .pro: nil
        }
    }

    /// Haftada gönderilebilecek buluşma isteği.
    var meetingRequestQuota: Int? {
        switch self {
        case .free: 3
        case .plus: 5
        case .pro: nil
        }
    }

    /// Haftada kabul edilebilecek buluşma isteği.
    var meetingAcceptQuota: Int? {
        switch self {
        case .free: 2
        case .plus: 5
        case .pro: nil
        }
    }

    // MARK: - Açık/kapalı özellikler

    /// Kendi mesajını silip düzenleyebilme.
    var canEditMessages: Bool { self >= .plus }

    /// Profiline kimlerin baktığını görebilme.
    var canSeeProfileVisitors: Bool { self >= .plus }

    /// Story izlerken duraklatabilme. Yalnızca Pro.
    var canPauseStory: Bool { self >= .pro }

    /// Story'yi kimin kaç kez izlediğini görebilme.
    var canSeeStoryViewCounts: Bool { self >= .pro }

    /// Hayalet mod: neye baktığın, kimin profiline girdiğin kimseye görünmez.
    var hasGhostMode: Bool { self >= .pro }
}

/// Paywall'daki karşılaştırma tablosunun tek kaynağı. Tabloyu elle yazmak,
/// bir kuralı değiştirdiğimizde tablonun eski kalması demekti.
struct PlanFeature: Identifiable, Sendable {
    let id: Int
    let label: String
    /// Kapanış `@Sendable`: tip paylaşılan sabit bir listede tutuluyor.
    let value: @Sendable (SubscriptionTier) -> String

    static let all: [PlanFeature] = [
        PlanFeature(id: 1, label: "Tanış'ta beğeni\n2 günde") { $0.likeQuota.map(String.init) ?? "∞" },
        PlanFeature(id: 2, label: "Buluşma isteği\nhaftada") { $0.meetingRequestQuota.map(String.init) ?? "∞" },
        PlanFeature(id: 3, label: "Buluşma kabulü\nhaftada") { $0.meetingAcceptQuota.map(String.init) ?? "∞" },
        PlanFeature(id: 4, label: "Profiline bakanlar") { $0.canSeeProfileVisitors ? "✓" : "—" },
        PlanFeature(id: 5, label: "Story'yi duraklatma") { $0.canPauseStory ? "✓" : "—" },
        PlanFeature(id: 6, label: "Mesaj silme ve\ndüzenleme") { $0.canEditMessages ? "✓" : "—" },
        PlanFeature(id: 7, label: "Story'mi kim kaç kez izledi") { $0.canSeeStoryViewCounts ? "✓" : "—" },
        PlanFeature(id: 8, label: "Hayalet mod") { $0.hasGhostMode ? "✓" : "—" }
    ]
}
