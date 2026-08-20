import Foundation

/// Abonelik kademesi.
///
/// Sıralı: `pro` her şeyi kapsar, `plus` yalnızca kendi düzeyini. Karşılaştırma
/// için `rawValue` kullanılıyor, böylece yeni bir kademe eklemek her kontrolü
/// tek tek gözden geçirmeyi gerektirmiyor.
enum SubscriptionTier: Int, Comparable, Codable {
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

    /// Tanış'ta 48 saatte kullanılabilecek beğeni hakkı.
    ///
    /// Bu sayı burada yalnızca arayüzde göstermek için; asıl sınır sunucuda
    /// uygulanıyor. İstemcideki bir sayaç, uygulamayı kurcalayan biri için
    /// hiçbir engel değil.
    var likeQuota: Int {
        switch self {
        case .free: 5
        case .plus, .pro: 10
        }
    }

    /// Kendi mesajını silip düzenleyebilme.
    var canEditMessages: Bool { self >= .plus }

    /// Story'yi kimin kaç kez izlediğini görme. Yalnızca Pro.
    var canSeeStoryViewCounts: Bool { self >= .pro }
}
