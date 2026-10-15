import SwiftUI

/// Sohbetin ortak görünümünde yapılan değişiklik. Sunucuda `messages.kind`
/// ('theme' / 'reaction') ve `messages.style_value`; sohbete "Ulaş sohbet
/// temasını Gece mavisi yaptı." satırı olarak düşer, iki taraf da görür.
/// `body` yine Türkçe cümle: eski sürümler ve bildirim onu gösteriyor.
enum ChatStyleChange: Hashable, Codable, Sendable {
    case theme(CardTheme)
    case reaction(String)

    var serverKind: String {
        switch self {
        case .theme: "theme"
        case .reaction: "reaction"
        }
    }

    var serverValue: String {
        switch self {
        case .theme(let tema): tema.rawValue
        case .reaction(let emoji): emoji
        }
    }

    /// Sunucudan gelen satır; düz mesajsa ya da değer tanınmıyorsa nil.
    init?(kind: String?, value: String?) {
        guard let value, !value.isEmpty else { return nil }
        switch kind {
        case "theme":
            guard let tema = CardTheme(rawValue: value) else { return nil }
            self = .theme(tema)
        case "reaction":
            self = .reaction(value)
        default:
            return nil
        }
    }

    /// Sohbetteki bilgi satırı ve sohbet listesindeki önizleme.
    func note(isMine: Bool, peerName: String) -> String {
        switch (self, isMine) {
        case (.theme(let tema), true): L10n.ChatStyle.themeChangedMine(tema.title)
        case (.theme(let tema), false): L10n.ChatStyle.themeChangedTheirs(peerName, tema.title)
        case (.reaction(let emoji), true): L10n.ChatStyle.reactionChangedMine(emoji)
        case (.reaction(let emoji), false): L10n.ChatStyle.reactionChangedTheirs(peerName, emoji)
        }
    }
}

/// Sohbetteki yazı boyutu. Kişisel: yalnızca bu telefonda, bütün sohbetlerde.
enum ChatTextSize: String, CaseIterable, Identifiable {
    case small, normal, large

    static let storageKey = "chatTextSize"

    var id: String { rawValue }

    var font: Font {
        switch self {
        case .small: .footnote
        case .normal: .subheadline
        case .large: .body
        }
    }

    var title: String {
        switch self {
        case .small: L10n.ChatStyle.sizeSmall
        case .normal: L10n.ChatStyle.sizeNormal
        case .large: L10n.ChatStyle.sizeLarge
        }
    }
}

/// Sohbet temaları kart temalarıyla aynı aile: aynı adlar, aynı zeminler.
/// Kendi balonun temanın koyu ya da açık eşi, yazısı en az 4,5:1 okunur.
/// Klasik bugünkü görünümün aynısı (mürekkep balon, kâğıt zemin).
extension CardTheme {
    /// Sohbetin zemini.
    var chatBackground: Color { background }

    /// Kendi mesajının balonu.
    var myBubble: Color {
        switch self {
        case .classic: BondTheme.ink
        case .ink: Color(hex: "F5F5F7")
        case .navy: Color(hex: "D6E1F7")
        case .terracotta: Color(hex: "FBE3D3")
        case .raspberry: Color(hex: "FADCE8")
        case .sage: Color(hex: "4E6B47")
        case .lavender: Color(hex: "5E4E99")
        case .rose: Color(hex: "A2485A")
        case .bubblegum: Color(hex: "B4306B")
        case .ocean: Color(hex: "2F6F86")
        }
    }

    /// Kendi balonundaki yazı.
    var myBubbleText: Color {
        switch self {
        case .classic: BondTheme.paper
        case .ink: Color(hex: "16181D")
        case .navy: Color(hex: "1B2A4A")
        case .terracotta: Color(hex: "7A3216")
        case .raspberry: Color(hex: "7E1F47")
        case .sage, .lavender, .rose, .bubblegum, .ocean: .white
        }
    }

    /// Karşının balonu. Renkli zeminde gri yüzey kirli duruyordu; koyu
    /// temada beyazın, açık temada kâğıdın yarı saydamı.
    var theirBubble: Color {
        switch self {
        case .classic: BondTheme.surface
        case .ink, .navy: Color.white.opacity(0.10)
        case .terracotta, .raspberry: Color.black.opacity(0.18)
        case .sage, .lavender, .rose, .bubblegum, .ocean: Color.white.opacity(0.72)
        }
    }

    /// Karşının balonunun çizgisi; yalnızca klasikte (beyaz zeminde ayrışsın).
    var theirBubbleStroke: Color { self == .classic ? BondTheme.hairline : .clear }

    /// Yazma alanının zemini: klasikte bugünkü yüzey, temalarda sohbetin zemini.
    var composerBackground: Color { self == .classic ? BondTheme.surface : background }

    /// Gönder düğmesi: temanın kendi balon rengi.
    var sendButton: Color { self == .classic ? BondTheme.ink : myBubble }
    var sendButtonIcon: Color { self == .classic ? BondTheme.paper : myBubbleText }
}
