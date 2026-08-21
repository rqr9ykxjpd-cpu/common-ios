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

    /// Birincil ön plan (yazı). Koyu modda açık tona döner.
    static let ink = adaptive(light: "121210", dark: "F2EFE7")
    /// Sayfa arka planı.
    static let paper = adaptive(light: "F2EFE7", dark: "121211")
    /// Kart/yüzey arka planı; sayfadan bir tık ayrışır.
    static let surface = adaptive(light: "FBFAF7", dark: "1D1D1A")
    static let muted = adaptive(light: "77746D", dark: "9A968D")

    /// Tasarımı gereği her iki modda da koyu kalan ekranların zemini (Tanış, story,
    /// eşleşme anı, kayıt sonu). Bunlar "sinema modu" gibi tasarlandı; `ink` ile
    /// birlikte dönselerdi beyaz zemin üzerinde beyaz yazı ortaya çıkardı.
    static let canvasDark = Color(hex: "121210")

    // Marka renkleri her iki modda da aynı kalır.
    static let acid = Color(hex: "D8FF52")

    /// `acid` zemin üstündeki yazı ve simgeler. Sabit koyu — `ink` kullanılamaz,
    /// çünkü o koyu modda beyaza dönüyor ve fıstık yeşili zeminde okunmaz hale
    /// geliyordu (paylaş düğmesi, rozetler, logo işareti, buluşma düğmesi...).
    static let onAccent = Color(hex: "121210")
    static let coral = Color(hex: "FF745E")
    /// Kurucu rengi. Uygulamanın hiçbir yerinde başka bir işi yok: bir yerde
    /// bu turuncuyu gören, kurucu hesabına baktığını biliyor. Fıstık yeşili
    /// (`acid`) bunu yapamıyordu — o renk zaten her ekrandaki ana eylem
    /// düğmesinin rengi, dolayısıyla hiçbir şeyi ayırt etmiyordu.
    static let ember = Color(hex: "D97757")
    static let violet = Color(hex: "8066FF")

    static let line = Color.white.opacity(0.13)
    static let hairline = ink.opacity(0.1)

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 18
        static let hero: CGFloat = 24
    }
}

struct EditorialTitle: ViewModifier {
    var size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .medium, design: .serif))
            .tracking(-1.4)
    }
}

extension View {
    func editorialTitle(_ size: CGFloat) -> some View {
        modifier(EditorialTitle(size: size))
    }
}

/// Native navigation bar'ı uygulamanın tipografisine ayarlar.
///
/// Ekranlar kendi başlıklarını çizmeyi bırakıp sistemin bar'ını kullanıyor.
/// Sistem bar'ı varsayılan olarak SF Pro kullanıyor; uygulamanın geri kalanı
/// yuvarlak varyantla yazılmış, dolayısıyla başlıklar tek başına ayrışıyordu.
///
/// Bunu sahte bir bar çizerek değil, `UINavigationBarAppearance` ile
/// çözüyoruz — bar hâlâ sistemin bar'ı: kaydırmadaki materyal geçişi, geri
/// düğmesi, büyük başlığın küçülmesi ve geçiş animasyonları sisteme ait.
enum NavigationBarStyle {
    static func install() {
        let gorunum = UINavigationBarAppearance()
        // `configureWithDefaultBackground`, iOS'un kendi materyalini bırakır:
        // kaydırınca beliren blur ve şeffaflık sistemin kararı olarak kalsın.
        gorunum.configureWithDefaultBackground()
        gorunum.largeTitleTextAttributes = [.font: yuvarlak(34, .bold)]
        gorunum.titleTextAttributes = [.font: yuvarlak(17, .semibold)]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = gorunum
        bar.compactAppearance = gorunum
        bar.scrollEdgeAppearance = gorunum
        bar.compactScrollEdgeAppearance = gorunum
    }

    /// Sistem yazı tipinin yuvarlak varyantı. Uygulamanın her yerinde
    /// `design: .rounded` kullanılıyor; UIKit tarafındaki karşılığı bu.
    private static func yuvarlak(_ boyut: CGFloat, _ agirlik: UIFont.Weight) -> UIFont {
        let temel = UIFont.systemFont(ofSize: boyut, weight: agirlik)
        guard let tanim = temel.fontDescriptor.withDesign(.rounded) else { return temel }
        return UIFont(descriptor: tanim, size: boyut)
    }
}

struct Wordmark: View {
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 9) {
            ZStack {
                Circle()
                    .fill(CampusTheme.acid)
                    .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)
                Circle()
                    .trim(from: 0.12, to: 0.84)
                    .stroke(CampusTheme.onAccent, style: StrokeStyle(lineWidth: compact ? 2 : 2.5, lineCap: .round))
                    .frame(width: compact ? 11 : 15, height: compact ? 11 : 15)
                    .rotationEffect(.degrees(-35))
            }
            Text("common")
                .font(.system(size: compact ? 17 : 21, weight: .semibold, design: .rounded))
                .tracking(-0.6)
        }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = CampusTheme.muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(color)
    }
}

struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<180 {
                let x = CGFloat((index * 47) % 173) / 173 * size.width
                let y = CGFloat((index * 83) % 191) / 191 * size.height
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.045)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct AppSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(CampusTheme.hairline))
        }
        .buttonStyle(PressableStyle())
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
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(background, in: RoundedRectangle(cornerRadius: CampusTheme.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.control, style: .continuous).stroke(role == .secondary ? CampusTheme.hairline : .clear))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.42)
    }

    private var foreground: Color {
        switch role {
        case .primary: CampusTheme.paper
        case .secondary: CampusTheme.ink
        case .accent: CampusTheme.onAccent
        }
    }

    private var background: Color {
        switch role {
        case .primary: CampusTheme.ink
        case .secondary: CampusTheme.surface
        case .accent: CampusTheme.acid
        }
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
            .overlay(RoundedRectangle(cornerRadius: CampusTheme.Radius.card, style: .continuous).stroke(CampusTheme.hairline))
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
                Button("Bitti") { KeyboardDismiss.now() }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
