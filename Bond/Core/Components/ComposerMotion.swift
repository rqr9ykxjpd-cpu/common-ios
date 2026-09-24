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

    /// Sınırı aşan kısmı sondan, bütün karakterler halinde keser (emojiyi ortadan bölmez).
    static func clamp(_ text: String, to limit: Int) -> String? {
        guard length(text) > limit else { return nil }
        var kesik = text
        while length(kesik) > limit, !kesik.isEmpty { kesik.removeLast() }
        return kesik
    }
}

/// Sınıra yaklaşınca beliren kalan karakter sayısı. Rakam kayarak azalır;
/// son %10'da turuncu, sınırda kırmızı. Sınırdan uzakken hiç görünmez —
/// sürekli duran bir sayaç yazan kişiyi gereksiz yere tedirgin eder.
struct CharacterCounter: View {
    let count: Int
    let limit: Int
    /// Sayaç bu orandan sonra görünür.
    var showsFrom: Double = 0.8

    static func isVisible(count: Int, limit: Int, showsFrom: Double = 0.8) -> Bool {
        Double(count) >= Double(limit) * showsFrom
    }

    var body: some View {
        let kalan = max(limit - count, 0)
        let renk: Color = kalan == 0 ? BondTheme.coral
            : (Double(kalan) <= Double(limit) * 0.1 ? BondTheme.burntOrange : BondTheme.muted)
        Text("\(kalan)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(renk)
            .contentTransition(.numericText(value: Double(kalan)))
            .animation(.snappy(duration: 0.2), value: kalan)
            .accessibilityLabel(L10n.Composer.charactersLeft(kalan))
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
}
