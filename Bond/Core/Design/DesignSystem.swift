import SwiftUI
import UIKit

// MARK: - Brand system

enum BondTheme {
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

    /// Yüksek öncelikli birincil eylem. İsim tarihsel (`acid`).
    ///
    /// Değer Apple mavisiydi ve beyaz zeminle birlikte Facebook/Messenger'ın
    /// birebir formülünü üretiyordu. Artık renk değil kontrast: açık modda
    /// siyah dolu kapsül, koyu modda beyaz. Renk yalnızca anlam taşıdığı yerde
    /// kalıyor — `coral` yıkıcı, `ember` kurucu.
    static let acid = adaptive(light: "1D1D1F", dark: "F5F5F7")
    /// `acid` zemin üstündeki yazı. `acid` moda göre ters çevrildiği için bu da
    /// çevrilmek zorunda; sabit beyaz kalsaydı koyu modda beyaz üstünde beyaz olurdu.
    static let onAccent = adaptive(light: "FFFFFF", dark: "1D1D1F")
    /// İkincil vurgu: story halkası, rozet dolgusu, yer iğnesi. İsim tarihsel
    /// (`violet`); bağlantı rengi değil, dekoratif kullanılıyor.
    static let violet = adaptive(light: "1D1D1F", dark: "F5F5F7")

    /// Her zaman koyu kalan yüzeylerde (Tanış kartı, story, eşleşme anı) vurgu.
    ///
    /// O ekranlar sistem renk şemasını zorlamıyor ama zeminleri siyah. `acid`
    /// oralarda açık mod değerine düşüp siyah üstünde siyah kalıyordu.
    static let onCanvasDark = Color(hex: "F5F5F7")
    /// Hata / yıkıcı eylem. Apple sistem kırmızısı; dekoratif accent değil.
    static let coral = adaptive(light: "FF3B30", dark: "FF453A")
    /// Kurucu rozeti. Paletin dışındaki tek semantik işaret — bir yerde bu
    /// rengi gören kurucu profiline baktığını bilir.
    static let ember = adaptive(light: "B85C3D", dark: "E89478")

    static let line = Color.white.opacity(0.18)
    /// Liste ayırıcı. Kart ve yüzeylerde kullanılmaz; secondary düğme ve List için.
    static let hairline = adaptive(light: "D2D2D7", dark: "38383A")

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let compact: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        /// Form alanı, satır ve ikincil içerik yüzeyi.
        static let surface: CGFloat = 16
        /// Büyük fotoğraf ve ürünün çekirdek medya yüzeyi.
        static let media: CGFloat = 24
    }

    enum Motion {
        static let duration: Double = 0.2
        static var easing: Animation { .easeOut(duration: duration) }
    }

    /// Sabit punto; sistem metin boyutu ayarıyla büyümez.
    ///
    /// Önce metin stili olarak tanımlıydılar (`.system(.headline, ...)`) ve
    /// sistem ayarıyla ölçekleniyorlardı. Uygulamanın geri kalanı ise sabit
    /// punto kullanıyordu — 233 sabite karşı 49 ölçeklenebilir. Sonuç tutarsızdı:
    /// çoğu ekran ayarı yok sayıyor, azınlık büyüyor ve bazıları kırılıyordu.
    /// Ayarlar ekranında "Şikayetler" kelimenin ortasından bölünüyordu.
    ///
    /// Değerler iOS'un varsayılan punto karşılıkları; varsayılan boyuttaki
    /// görünüm birebir aynı kaldı, yalnızca büyümesi durdu.
    enum Typography {
        static var largeTitle: Font { .system(size: 34, weight: .semibold) }
        static var title: Font { .system(size: 28, weight: .semibold) }
        static var title2: Font { .system(size: 22, weight: .semibold) }
        static var title3: Font { .system(size: 20, weight: .semibold) }
        static var heading: Font { .system(size: 20, weight: .semibold) }
        static var headline: Font { .system(size: 17, weight: .semibold) }
        static var subheadline: Font { .system(size: 15) }
        static var body: Font { .system(size: 17) }
        static var callout: Font { .system(size: 16) }
        static var footnote: Font { .system(size: 13) }
        static var caption: Font { .system(size: 12) }
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

/// Marka adı.
///
/// Sistem yazı tipiyle yazılınca logo değil etiket gibi duruyordu — ekrandaki
/// başka herhangi bir başlıktan ayırt edilemiyordu. İkondaki "b" ile aynı
/// kesimde (New York, sistem yazı tipinin serif varyantı) yazılıyor; harfin
/// kendisi işaret olduğu için ayrıca bir amblem gerekmiyor.
///
/// Harfler açılışta sırayla beliriyor. Animasyon bir kez, ~0.5 saniye:
/// akış günde onlarca kez açılan bir ekran, sürekli dönen bir şey orada
/// gürültü olurdu.
struct Wordmark: View {
    var compact = false

    @State private var belirdi = false

    private var harfler: [(index: Int, karakter: Character)] {
        Array(L10n.Brand.wordmark).enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(harfler, id: \.index) { harf in
                Text(String(harf.karakter))
                    .opacity(belirdi ? 1 : 0)
                    .offset(y: belirdi ? 0 : 7)
                    .blur(radius: belirdi ? 0 : 3)
                    .animation(.smooth(duration: 0.42).delay(Double(harf.index) * 0.055),
                               value: belirdi)
            }
        }
        .font(.system(size: compact ? 18 : 23, weight: .bold, design: .serif))
        .tracking(-0.6)
        .foregroundStyle(BondTheme.ink)
        .fixedSize()
        // Harf harf bölündüğü için sesli okuyucu "b-o-n-d" demesin.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Brand.wordmark)
        .accessibilityAddTraits(.isHeader)
        .onAppear { belirdi = true }
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = BondTheme.muted

    var body: some View {
        Text(text)
            .font(BondTheme.Typography.caption.weight(.medium))
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
            .animation(BondTheme.Motion.easing, value: configuration.isPressed)
    }
}

struct AppSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(BondTheme.Typography.title3)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(BondTheme.Typography.footnote.weight(.medium))
                    .foregroundStyle(BondTheme.violet)
            }
        }
        .foregroundStyle(BondTheme.ink)
    }
}

struct AppIconButton: View {
    let systemName: String
    var tint: Color = BondTheme.ink
    var fill: Color = BondTheme.surface
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
            HStack(spacing: BondTheme.Space.sm) {
                if let systemName { Image(systemName: systemName) }
                Text(title)
            }
            .font(BondTheme.Typography.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(background, in: Capsule())
            .overlay {
                if role == .secondary {
                    Capsule().stroke(BondTheme.hairline, lineWidth: 1)
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
        case .primary, .accent: BondTheme.onAccent
        case .secondary: BondTheme.ink
        }
    }

    private var background: Color {
        switch role {
        case .primary, .accent: BondTheme.acid
        case .secondary: BondTheme.surface
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
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .font(BondTheme.Typography.body)
            .foregroundStyle(BondTheme.violet)
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
            .padding(BondTheme.Space.lg)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
    }
}

struct AppEmptyState: View {
    var systemImage: String
    var title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: BondTheme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(BondTheme.icon)
                .frame(width: 44, height: 44)
            Text(title)
                .font(BondTheme.Typography.title3)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(BondTheme.Typography.body.weight(.medium))
                    .foregroundStyle(BondTheme.violet)
                    .frame(minHeight: 44)
            }
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, BondTheme.Space.xxl)
        .padding(.horizontal, BondTheme.Space.lg)
    }
}

struct AppLoadingView: View {
    var message: String = L10n.Common.loading

    var body: some View {
        VStack(spacing: BondTheme.Space.md) {
            ProgressView()
                .tint(BondTheme.acid)
            Text(message)
                .font(BondTheme.Typography.footnote)
                .foregroundStyle(BondTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BondTheme.Space.xxl)
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
                    .font(BondTheme.Typography.body.weight(.semibold))
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
