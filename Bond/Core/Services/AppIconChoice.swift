import UIKit

/// Ana ekran simgesi. Renkli simgeler herkese açık, altınlar Plus/Pro'ya özel;
/// seçim yalnızca bu telefonda geçerli, kimse başkasının simgesini görmüyor
/// ("planını yalnızca sen görürsün" sözü bozulmasın).
///
/// Simge setleri `Assets.xcassets` içinde; derlemeye
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` ile giriyorlar
/// (Config/Bond.xcconfig). Önizlemeler ayrı imageset: simge setleri
/// `UIImage(named:)` ile okunamıyor.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case classic
    case pink
    case lightPink
    case red
    case blue
    case goldNight
    case gold

    var id: String { rawValue }

    /// `setAlternateIconName`'e giden ad; klasik simge için nil.
    var iconName: String? {
        switch self {
        case .classic: nil
        case .pink: "AppIconPink"
        case .lightPink: "AppIconLightPink"
        case .red: "AppIconRed"
        case .blue: "AppIconBlue"
        case .goldNight: "AppIconGoldNight"
        case .gold: "AppIconGold"
        }
    }

    var title: String {
        switch self {
        case .classic: L10n.PlanPerks.iconClassic
        case .pink: L10n.PlanPerks.iconPink
        case .lightPink: L10n.PlanPerks.iconLightPink
        case .red: L10n.PlanPerks.iconRed
        case .blue: L10n.PlanPerks.iconBlue
        case .goldNight: L10n.PlanPerks.iconGoldNight
        case .gold: L10n.PlanPerks.iconGold
        }
    }

    var previewAsset: String {
        switch self {
        case .classic: "IconPreviewClassic"
        case .pink: "IconPreviewPink"
        case .lightPink: "IconPreviewLightPink"
        case .red: "IconPreviewRed"
        case .blue: "IconPreviewBlue"
        case .goldNight: "IconPreviewGoldNight"
        case .gold: "IconPreviewGold"
        }
    }

    /// Plus/Pro'ya özel olanlar. Abonelik bitince yalnızca bunlar geri alınır.
    var isGold: Bool { self == .gold || self == .goldNight }

    @MainActor
    static var current: AppIconChoice {
        let ad = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == ad } ?? .classic
    }

    /// Simgeyi değiştirir. iOS kendi "simgeyi değiştirdiniz" uyarısını gösterir.
    @MainActor
    func apply() async throws {
        guard UIApplication.shared.supportsAlternateIcons, Self.current != self else { return }
        try await UIApplication.shared.setAlternateIconName(iconName)
    }

    /// Abonelik bittiyse altın simgeyi geri alır. Yalnızca sunucu planın
    /// 'free' olduğunu söylediğinde çağrılıyor; ağ hatasında parası ödenmiş
    /// kullanıcının simgesi yanlışlıkla gitmesin.
    @MainActor
    static func resetIfLapsed(tier: SubscriptionTier) async {
        guard tier == .free, current.isGold else { return }
        try? await AppIconChoice.classic.apply()
    }
}
