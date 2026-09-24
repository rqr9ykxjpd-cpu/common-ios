import SwiftUI

/// Yazı alanı boşken içinde soluk duran ipucu; birkaç saniyede bir yumuşakça
/// bir sonrakine geçer. Ne yazacağını bilemeyen kişiye fikir veriyor.
///
/// Yazmaya başlanınca çağıran bunu kaldırır, döngü de kendiliğinden durur.
/// "Hareketi Azalt" açıksa yalnızca ilk ipucu görünür, hiç dönmez.
struct RotatingPlaceholder: View {
    let prompts: [String]
    var interval: Duration = .seconds(3.4)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    var body: some View {
        let current = prompts.isEmpty ? "" : prompts[index % prompts.count]
        Text(current)
            .id(current)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity.combined(with: .offset(y: -8))
            ))
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: prompts) {
                index = 0
                guard prompts.count > 1, !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.5)) { index += 1 }
                }
            }
    }
}

/// Sunucudaki karakter sınırlarıyla aynı sayım. Postgres `char_length` kod
/// noktası sayar; Swift'in `count`'u ise bir bayrak emojisini 1 sayıyor. Aynı
/// ölçüyü kullanmazsak sayaç "sığıyor" derken sunucu reddedebilirdi.
enum TextLimit {
    static let post = 2200
    static let story = 280
    static let comment = 1000
    static let message = 2000

    static func length(_ text: String) -> Int { text.unicodeScalars.count }

    static func fits(_ text: String, _ limit: Int) -> Bool { length(text) <= limit }

    /// Yazı bu değişiklikle sınırı yeni mi aştı? Titreme ve uyarı titreşimi
    /// yalnızca aşıldığı an bir kez; aşıkken yazmaya devam etmek her harfte titretmesin.
    ///
    /// Yazıyı kendimiz kısaltmıyoruz: alanın içeriğini programla değiştirmek
    /// imleci metnin ortasına atlatıyor, sonraki harfler yanlış yere giriyordu.
    /// Aşan kısım kırmızı eksi sayaçla gösteriliyor, gönder düğmesi kapanıyor.
    static func crossed(from old: String, to new: String, _ limit: Int) -> Bool {
        fits(old, limit) && !fits(new, limit)
    }
}

/// Sınıra yaklaşınca beliren kalan karakter sayısı. Rakam kayarak azalır;
/// son %10'da turuncu, sınır aşılınca kırmızı eksi. Sınırdan uzakken hiç
/// görünmez — sürekli duran bir sayaç yazan kişiyi gereksiz yere tedirgin eder.
struct CharacterCounter: View {
    let count: Int
    let limit: Int
    /// Sayaç bu orandan sonra görünür.
    var showsFrom: Double = 0.8

    static func isVisible(count: Int, limit: Int, showsFrom: Double = 0.8) -> Bool {
        Double(count) >= Double(limit) * showsFrom
    }

    var body: some View {
        let kalan = limit - count
        let renk: Color = kalan < 0 ? BondTheme.coral
            : (Double(kalan) <= Double(limit) * 0.1 ? BondTheme.burntOrange : BondTheme.muted)
        Text("\(kalan)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(renk)
            .contentTransition(.numericText(value: Double(kalan)))
            .animation(.snappy(duration: 0.2), value: kalan)
            .accessibilityLabel(L10n.Composer.charactersLeft(max(kalan, 0)))
    }
}

/// Sınıra dayanınca alanın kısa, iki yönlü titremesi (hayır anlamında baş sallama).
struct LimitShake: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-6, duration: 0.06)
                    CubicKeyframe(5, duration: 0.08)
                    CubicKeyframe(-3, duration: 0.08)
                    SpringKeyframe(0, duration: 0.2, spring: .snappy)
                }
            }
        }
    }
}

extension View {
    func limitShake(trigger: Int) -> some View { modifier(LimitShake(trigger: trigger)) }

    /// Yuvarlak yazma alanları (sohbet, yorum) için: sınıra yaklaşınca alanın
    /// sağ altında kalan sayıyı gösterir, sınır aşıldığı an alanı titretir.
    /// Gönder düğmesini kapatmak çağıranın işi (`TextLimit.fits`).
    func composerLimit(text: Binding<String>, limit: Int, bump: Binding<Int>) -> some View {
        modifier(ComposerLimit(text: text, limit: limit, bump: bump))
    }
}

private struct ComposerLimit: ViewModifier {
    @Binding var text: String
    let limit: Int
    @Binding var bump: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let sayi = TextLimit.length(text)
        let gorunur = CharacterCounter.isVisible(count: sayi, limit: limit)
        content
            .overlay(alignment: .bottomTrailing) {
                if gorunur {
                    CharacterCounter(count: sayi, limit: limit)
                        .padding(.horizontal, 6)
                        .background(.background, in: Capsule())
                        .offset(x: -10, y: 9)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: gorunur)
            .limitShake(trigger: bump)
            .sensoryFeedback(.warning, trigger: bump)
            .onChange(of: text) { eski, yeni in
                if TextLimit.crossed(from: eski, to: yeni, limit) { bump += 1 }
            }
    }
}

/// Sohbet ve yorumlardaki yuvarlak gönder düğmesi. Yazı yokken biraz geride
/// ve soluk; ilk harfle öne çıkıp dolar. Gönderince ok yukarı fırlayıp alttan
/// geri gelir. Düzenlerken ok tike dönüşür, fırlamaz.
struct SendArrowButton: View {
    let canSend: Bool
    var isEditing = false
    let accessibilityLabel: String
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launches = 0

    var body: some View {
        Button {
            guard canSend else { return }
            if !isEditing, !reduceMotion { launches += 1 }
            action()
        } label: {
            Image(systemName: isEditing ? "checkmark" : "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BondTheme.paper)
                .contentTransition(.symbolEffect(.replace))
                .keyframeAnimator(initialValue: SendLaunch(), trigger: launches) { icon, frame in
                    icon.offset(y: frame.y).opacity(frame.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.y) {
                        CubicKeyframe(-30, duration: 0.16)
                        MoveKeyframe(22)
                        SpringKeyframe(0, duration: 0.34, spring: .snappy)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.16)
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.2)
                    }
                }
                .frame(width: 44, height: 44)
                .background(canSend ? BondTheme.ink : BondTheme.ink.opacity(0.22), in: Circle())
                .clipShape(Circle())
                .scaleEffect(canSend || reduceMotion ? 1 : 0.86)
        }
        .accessibilityLabel(accessibilityLabel)
        .disabled(!canSend)
        .buttonStyle(PressableStyle())
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: canSend)
    }
}

/// Gönder okunun fırlama karesi.
private struct SendLaunch {
    var y: CGFloat = 0
    var opacity: Double = 1
}
