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
    /// İkincil yazı (kullanıcı adı, bölüm, ipuçları). Sistemin grisi orta
    /// tonlu zeminlerde okunmuyordu: kiremitte 1,7:1. Koyu renklerde beyazdan,
    /// açık renklerde mürekkepten türüyor; hepsi en az 4:1.
    var secondaryText: Color {
        switch self {
        case .classic, .ink, .navy: BondTheme.muted
        case .terracotta, .raspberry: Color.white.opacity(0.86)
        case .sage, .lavender, .rose, .bubblegum, .ocean: BondTheme.ink.opacity(0.68)
        }
    }

    /// Bölüm çizgileri: gri çizgi renkli zeminde kirli duruyordu.
    var rule: Color {
        self == .classic ? BondTheme.hairline.opacity(0.8) : BondTheme.ink.opacity(0.14)
    }

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

/// Kartın zemini: renk ve renkli temalarda hafif çapraz çizgiler. Klasik düz:
/// varsayılan kart sade kalsın, çizgi seçilen rengin imzası olsun. Hem
/// "Kartını düzenle"deki kart hem profil kartı bunu kullanıyor.
struct CardThemeSurface: View {
    let theme: CardTheme
    /// Bu yüzeyin sol üst köşesinin ortak bir düzlemdeki yeri. Profil
    /// sayfasında zemin, kart ve alt şerit ayrı yüzeyler; hepsi aynı düzleme
    /// hizalanınca çizgiler birleştikleri yerde kırılmıyor.
    var origin: CGPoint = .zero
    /// Verilirse çizgiler düzlemin başlangıcından (kartın üst kenarı) bu kadar
    /// aşağıda tamamen söner. Kartın üstünde kalan yüzeyde (üst çubuğun
    /// arkası) tam görünür; birleşme yerinde iki yüzey aynı tonda.
    var fadeOut: CGFloat? = nil

    var body: some View {
        ZStack {
            theme.background
            if theme != .classic {
                CardStripes(phase: origin.x + origin.y)
                    .stroke(BondTheme.ink.opacity(theme.scheme == .dark ? 0.06 : 0.035), lineWidth: 10)
                    .mask {
                        if let fadeOut {
                            VStack(spacing: 0) {
                                Color.black.frame(height: max(0, -origin.y))
                                LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                                    .frame(height: fadeOut)
                                Color.clear
                            }
                        } else {
                            Color.black
                        }
                    }
            }
        }
        // Çizgiler kenarın dışına taşıyor (bkz. CardStripes); komşu yüzeyin
        // üstüne binip orayı koyulaştırmasın.
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Yerini kendisi ölçen zemin: sayfada sabit duran yüzeyler için (arka zemin,
/// alt şerit). `space` sayfanın ortak koordinat düzlemi.
struct AlignedCardThemeSurface: View {
    let theme: CardTheme
    let space: String
    var fadeOut: CGFloat? = nil
    @State private var origin: CGPoint = .zero

    var body: some View {
        CardThemeSurface(theme: theme, origin: origin, fadeOut: fadeOut)
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .named(space)).origin } action: { origin = $0 }
    }
}

/// Çapraz çizgiler (x + y = sabit), 26 pt arayla. `phase` çizgileri ortak
/// düzleme oturtuyor: yüzey nerede durursa dursun aynı ızgaraya denk geliyor.
/// Her çizgi üstte ve altta kenarı `tasma` kadar aşıyor: kenarda biten kalın
/// çizginin ucu çapraz kesildiği için iki yüzeyin birleştiği yerde küçük
/// üçgen boşluklar kalıyordu.
struct CardStripes: Shape {
    var phase: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let aralik: CGFloat = 26
        let tasma: CGFloat = 12
        let kayma = (-phase).truncatingRemainder(dividingBy: aralik)
        var c = (kayma < 0 ? kayma + aralik : kayma) - aralik
        while c < rect.width + rect.height + aralik {
            path.move(to: CGPoint(x: rect.minX + c - rect.height - tasma, y: rect.maxY + tasma))
            path.addLine(to: CGPoint(x: rect.minX + c + tasma, y: rect.minY - tasma))
            c += aralik
        }
        return path
    }
}
