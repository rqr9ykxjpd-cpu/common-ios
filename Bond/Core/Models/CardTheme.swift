import SwiftUI

/// Profil kartının rengi. Kullanıcı "Kartını düzenle"den seçer, kartı açan
/// herkes bu renkte görür. Sunucudaki `profiles.card_theme`; klasik = `nil`.
///
/// Serbest renk seçici yerine seçilmiş bir palet: her renkte yazı okunur ve
/// hiçbir kart kötü görünmez. Altın yok; altın Plus/Pro'ya ayrılmış, kartta
/// görünse "planını yalnızca sen görürsün" sözü bozulurdu.
///
/// Kart kendi renk şemasını alıyor (`scheme`): koyu zeminde `BondTheme`'in
/// adaptif renkleri kendiliğinden açığa döner, yazılar tek tek boyanmaz.
/// Değerler sunucudaki kısıtla aynı (`20260927010000_card_theme.sql`, pembeler
/// `20260927050000_card_theme_pinks.sql`).
enum CardTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case classic
    case ink
    case navy
    case terracotta
    case raspberry
    case sage
    case lavender
    case rose
    case bubblegum
    case ocean

    var id: String { rawValue }

    /// Kartın zemini. Klasik, uygulamanın kâğıdı: telefonun açık/koyu moduna uyar.
    var background: Color {
        switch self {
        case .classic: BondTheme.paper
        case .ink: Color(hex: "16181D")
        case .navy: Color(hex: "1B2A4A")
        case .terracotta: Color(hex: "B4532A")
        case .raspberry: Color(hex: "B8336A")
        case .sage: Color(hex: "DCE5D6")
        case .lavender: Color(hex: "E4DEF3")
        case .rose: Color(hex: "F3D9DC")
        case .bubblegum: Color(hex: "F7B9D1")
        case .ocean: Color(hex: "D5E8EE")
        }
    }

    /// Kartın renk şeması; `nil` = telefonunki.
    var scheme: ColorScheme? {
        switch self {
        case .classic: nil
        case .ink, .navy, .terracotta, .raspberry: .dark
        case .sage, .lavender, .rose, .bubblegum, .ocean: .light
        }
    }

    var title: String {
        switch self {
        case .classic: L10n.CardStudio.classic
        case .ink: L10n.CardStudio.ink
        case .navy: L10n.CardStudio.navy
        case .terracotta: L10n.CardStudio.terracotta
        case .raspberry: L10n.CardStudio.raspberry
        case .sage: L10n.CardStudio.sage
        case .lavender: L10n.CardStudio.lavender
        case .rose: L10n.CardStudio.rose
        case .bubblegum: L10n.CardStudio.bubblegum
        case .ocean: L10n.CardStudio.ocean
        }
    }

    /// Sunucudan gelen değer; tanınmayan ya da boş değer klasiktir.
    init(server value: String?) {
        self = value.flatMap(CardTheme.init(rawValue:)) ?? .classic
    }

    /// Sunucuya giden değer; klasik `nil` olarak saklanıyor.
    var serverValue: String? { self == .classic ? nil : rawValue }
}
