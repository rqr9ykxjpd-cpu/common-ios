import SwiftUI
import UIKit

// MARK: - Brand system

enum CampusTheme {
    /// Renk şemasına göre değişen renk. `UIColor` üzerinden tanımlandığı için çağrı
    /// yerlerine dokunmadan tüm uygulamada koyu moda uyum sağlar.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// Birincil ön plan (yazı).
    static let ink = adaptive(light: "1D1D1F", dark: "F5F5F7")
    /// Sayfa tuvali.
    static let paper = adaptive(light: "FFFFFF", dark: "000000")
    /// Bölüm / kart yüzeyi; tuvalden spacing ile ayrılır, border gerekmez.
    static let surface = adaptive(light: "F5F5F7", dark: "1C1C1E")
    /// İkincil metin.
    static let muted = adaptive(light: "707070", dark: "98989D")
    /// İkon ve daha düşük kontrastlı metin.
    static let icon = adaptive(light: "474747", dark: "8E8E93")

    /// Medya / tam ekran görseller (story, tanış kartı). Siyah kalır; içerik rengi taşır.
    static let canvasDark = Color(hex: "000000")

    /// Yüksek öncelikli birincil eylem. İsim tarihsel (`acid`); değer Apple mavisi.
    static let acid = adaptive(light: "0071E3", dark: "0A84FF")
    /// `acid` zemin üstündeki yazı — her iki modda beyaz.
    static let onAccent = Color(hex: "FFFFFF")
    /// Metin bağlantısı. İsim tarihsel (`violet`).
    static let violet = adaptive(light: "0066CC", dark: "2997FF")
    /// Hata / yıkıcı eylem. Apple sistem kırmızısı; dekoratif accent değil.
    static let coral = adaptive(light: "FF3B30", dark: "FF453A")
    /// Kurucu rozeti. Paletin dışındaki tek semantik işaret — bir yerde bu
    /// rengi gören kurucu profiline baktığını bilir.
    static let ember = Color(hex: "D97757")

    static let line = Color.white.opacity(0.18)
    /// Liste ayırıcı. Kart ve yüzeylerde kullanılmaz; secondary düğme ve List için.
    static let hairline = adaptive(light: "D2D2D7", dark: "38383A")

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    enum Radius {
        /// Pill kontroller. `Capsule` tercih edilir; RoundedRectangle için yeterince büyük.
        static let control: CGFloat = 100
        static let card: CGFloat = 28
        static let hero: CGFloat = 28
    }

    enum Motion {
        static let duration: Double = 0.2
        static var easing: Animation { .easeOut(duration: duration) }
    }

    enum Typography {
        static var largeTitle: Font { .system(.largeTitle, design: .default).weight(.semibold) }
        static var title: Font { .system(.title, design: .default).weight(.semibold) }
        static var title2: Font { .system(.title2, design: .default).weight(.semibold) }
        static var title3: Font { .system(.title3, design: .default).weight(.semibold) }
        static var heading: Font { .system(.title3, design: .default).weight(.semibold) }
        static var body: Font { .system(.body, design: .default) }
        static var callout: Font { .system(.callout, design: .default) }
        static var footnote: Font { .system(.footnote, design: .default) }
        static var caption: Font { .system(.caption, design: .default) }
    }
}

// MARK: - Typography

struct EditorialTitle: ViewModifier {
    var size: CGFloat
    @ScaledMetric private var scaled: CGFloat

    init(size: CGFloat) {
        self.size = size
        _scaled = ScaledMetric(wrappedValue: min(max(size, 28), 40), relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaled, weight: .semibold, design: .default))
            .tracking(-0.4)
    }
}

struct CampusDisplay: ViewModifier {
    var size: CGFloat
    @ScaledMetric private var scaled: CGFloat

    init(size: CGFloat) {
        self.size = size
        _scaled = ScaledMetric(wrappedValue: min(max(size, 28), 40), relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaled, weight: .semibold, design: .default))
            .tracking(-0.35)
    }
}

struct CampusHeading: ViewModifier {
    var size: CGFloat
    @ScaledMetric private var scaled: CGFloat

    init(size: CGFloat) {
        self.size = size
        _scaled = ScaledMetric(wrappedValue: min(max(size, 20), 28), relativeTo: .title2)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaled, weight: .semibold, design: .default))
    }
}

struct CampusBody: ViewModifier {
    var size: CGFloat
    @ScaledMetric private var scaled: CGFloat

    init(size: CGFloat) {
        self.size = size
        _scaled = ScaledMetric(wrappedValue: min(max(size, 15), 17), relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaled, weight: .regular, design: .default))
    }
}

extension View {
    func editorialTitle(_ size: CGFloat) -> some View {
        modifier(EditorialTitle(size: size))
    }

    func campusDisplay(_ size: CGFloat = 34) -> some View {
        modifier(CampusDisplay(size: size))
    }

    func campusHeading(_ size: CGFloat = 22) -> some View {
        modifier(CampusHeading(size: size))
    }

    func campusBody(_ size: CGFloat = 17) -> some View {
        modifier(CampusBody(size: size))
    }
}

/// Native navigation bar — sistem SF Pro, yuvarlak varyant yok.
enum NavigationBarStyle {
    @MainActor
    static func install() {
        let gorunum = UINavigationBarAppearance()
        gorunum.configureWithDefaultBackground()
        gorunum.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        gorunum.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = gorunum
        bar.compactAppearance = gorunum
        bar.scrollEdgeAppearance = gorunum
        bar.compactScrollEdgeAppearance = gorunum
    }
}

struct Wordmark: View {
    var compact = false

    var body: some View {
        Text(L10n.Brand.wordmark)
            .font(.system(size: compact ? 17 : 21, weight: .semibold, design: .default))
            .tracking(-0.4)
            .foregroundStyle(CampusTheme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = CampusTheme.muted

    var body: some View {
        Text(text)
            .font(CampusTheme.Typography.caption.weight(.medium))
            .foregroundStyle(color)
    }
}

/// Eski dekoratif tane dokusu. Çağrı yerlerini kırmamak için durur; çizmeyi bırakır.
struct GrainOverlay: View {
    var body: some View {
        Color.clear.allowsHitTesting(false)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(CampusTheme.Motion.easing, value: configuration.isPressed)
    }
}

struct AppSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(CampusTheme.Typography.title3)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(CampusTheme.Typography.footnote.weight(.medium))
                    .foregroundStyle(CampusTheme.violet)
            }
        }
        .foregroundStyle(CampusTheme.ink)
    }
}

struct AppIconButton: View {
    let systemName: String
    var tint: Color = CampusTheme.ink
    var fill: Color = CampusTheme.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(systemName))
    }
}

struct AppButton: View {
    let title: String
    var systemName: String? = nil
    var role: Style = .primary
    var enabled = true
    let action: () -> Void

    enum Style { case primary, secondary, accent }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CampusTheme.Space.sm) {
                if let systemName { Image(systemName: systemName) }
                Text(title)
            }
            .font(CampusTheme.Typography.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(background, in: Capsule())
            .overlay {
                if role == .secondary {
                    Capsule().stroke(CampusTheme.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch role {
        case .primary, .accent: CampusTheme.onAccent
        case .secondary: CampusTheme.ink
        }
    }

    private var background: Color {
        switch role {
        case .primary, .accent: CampusTheme.acid
        case .secondary: CampusTheme.surface
        }
    }
}

struct AppTextLink: View {
    let title: String
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                }
            }
            .font(CampusTheme.Typography.body)
            .foregroundStyle(CampusTheme.violet)
            .frame(minHeight: 44)
        }
        .buttonStyle(PressableStyle())
    }
}

struct AppSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(CampusTheme.Space.lg)
            .background(CampusTheme.surface, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous))
    }
}

struct AppEmptyState: View {
    var systemImage: String
    var title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: CampusTheme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(CampusTheme.icon)
                .frame(width: 44, height: 44)
            Text(title)
                .font(CampusTheme.Typography.title3)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(CampusTheme.Typography.footnote)
                    .foregroundStyle(CampusTheme.muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(CampusTheme.Typography.body.weight(.medium))
                    .foregroundStyle(CampusTheme.violet)
                    .frame(minHeight: 44)
            }
        }
        .foregroundStyle(CampusTheme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, CampusTheme.Space.xxxl)
        .padding(.horizontal, CampusTheme.Space.lg)
    }
}

struct AppLoadingView: View {
    var message: String = L10n.Common.loading

    var body: some View {
        VStack(spacing: CampusTheme.Space.md) {
            ProgressView()
                .tint(CampusTheme.acid)
            Text(message)
                .font(CampusTheme.Typography.footnote)
                .foregroundStyle(CampusTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CampusTheme.Space.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}


// MARK: - Klavye

extension View {
    /// Boş bir yere dokununca klavyeyi kapatır.
    ///
    /// `simultaneousGesture` kullanılıyor: `onTapGesture` alttaki düğme ve alanların
    /// dokunuşlarını yiyebiliyor, bu ise onlarla birlikte çalışıyor.
    func dismissesKeyboardOnTap() -> some View {
        simultaneousGesture(TapGesture().onEnded { @MainActor in KeyboardDismiss.now() })
    }
}

enum KeyboardDismiss {
    @MainActor
    static func now() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Klavyenin üstünde "Bitti" düğmesi. Tarih seçiciye ulaşmak için klavyeyi kapatmak
/// gerekiyordu ve kapatmanın görünür bir yolu yoktu.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.Common.done) { KeyboardDismiss.now() }
                    .font(CampusTheme.Typography.body.weight(.semibold))
            }
        }
    }
}

extension View {
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneToolbar()) }
}

enum AgeLimit {
    /// Kayıt için en geç doğum tarihi (18 yaş). Zorla açma yerine `.now` ile
    /// güvenli düşüş: takvim hesabı teoride nil dönebiliyor.
    static var latestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b: UInt64
        (r, g, b) = ((value >> 16) & 255, (value >> 8) & 255, value & 255)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
