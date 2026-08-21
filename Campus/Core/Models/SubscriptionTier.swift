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

    /// Sunucudaki `subscriptions.plan` metni. Bilinmeyen bir değer 'free'
    /// sayılıyor: sunucuya sonradan eklenen bir kademe, eski uygulamada
    /// kilitleri açmamalı.
    init(serverValue: String) {
        switch serverValue {
        case "plus": self = .plus
        case "pro": self = .pro
        default: self = .free
        }
    }

    var serverValue: String {
        switch self {
        case .free: "free"
        case .plus: "plus"
        case .pro: "pro"
        }
    }

    var title: String {
        switch self {
        case .free: L10n.Tier.free
        case .plus: L10n.Tier.plus
        case .pro: L10n.Tier.pro
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
        PlanFeature(id: 1, label: L10n.Paywall.featureLikes) { $0.likeQuota.map(String.init) ?? L10n.Paywall.infinity },
        PlanFeature(id: 2, label: L10n.Paywall.featureRequests) { $0.meetingRequestQuota.map(String.init) ?? L10n.Paywall.infinity },
        PlanFeature(id: 3, label: L10n.Paywall.featureAccepts) { $0.meetingAcceptQuota.map(String.init) ?? L10n.Paywall.infinity },
        PlanFeature(id: 4, label: L10n.Paywall.featureVisitors) { $0.canSeeProfileVisitors ? L10n.Paywall.yes : L10n.Paywall.no },
        PlanFeature(id: 5, label: L10n.Paywall.featurePause) { $0.canPauseStory ? L10n.Paywall.yes : L10n.Paywall.no },
        PlanFeature(id: 6, label: L10n.Paywall.featureEdit) { $0.canEditMessages ? L10n.Paywall.yes : L10n.Paywall.no },
        PlanFeature(id: 7, label: L10n.Paywall.featureViewCounts) { $0.canSeeStoryViewCounts ? L10n.Paywall.yes : L10n.Paywall.no },
        PlanFeature(id: 8, label: L10n.Paywall.featureGhost) { $0.hasGhostMode ? L10n.Paywall.yes : L10n.Paywall.no }
    ]
}
