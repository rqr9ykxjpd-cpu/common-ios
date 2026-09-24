import SwiftUI

/// Plus'ın rengi: altın. Uygulamanın geri kalanı bilerek siyah-beyaz; altın
/// yalnızca "Plus" anlamına ayrıldı ki görünce ne olduğu hemen anlaşılsın.
enum PlusGold {
    static let light = Color(hex: "FFD84D")
    static let deep = Color(hex: "F2A900")
    /// Altın zemin iki modda da açık; üstündeki yazı her zaman koyu.
    static let ink = Color(hex: "1D1D1F")
    static var gradient: LinearGradient {
        LinearGradient(colors: [light, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Profildeki plan kutucuğu, altın. Birkaç saniyede bir üstünden çapraz bir
/// ışık geçer; o anda "+" çeyrek tur dönüp büyür, köşede iki küçük yıldız
/// parıldar. Ücretsiz kullanıcıda davet olarak düzenli tekrarlar; Plus/Pro
/// olanda yalnızca açılışta bir kez.
///
/// Hareket yalnızca ekrandayken çalışıyor (görünüm kaybolunca döngü iptal);
/// "Hareketi Azalt" ya da Düşük Güç Modu açıkken kutucuk durgun.
struct PlusGoldTile: View {
    let title: String
    let value: String
    /// Ücretsiz kullanıcı: parlama tekrar eder.
    let invites: Bool
    var minHeight: CGFloat = 108
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// -1: ışık bandı solda, görünmez; 1: sağdan çıkmış.
    @State private var sweep: CGFloat = -1
    @State private var twinkle = 0

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(PlusGold.deep)
                    .keyframeAnimator(initialValue: PlusTwist(), trigger: twinkle) { plus, frame in
                        plus.rotationEffect(.degrees(frame.angle)).scaleEffect(frame.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.angle) {
                            LinearKeyframe(0, duration: 0.25)
                            SpringKeyframe(90, duration: 0.55, spring: .bouncy)
                        }
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(1, duration: 0.25)
                            CubicKeyframe(1.3, duration: 0.2)
                            SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(.white, in: Circle())

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(value)
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(PlusGold.ink)
            .padding(BondTheme.Space.compact)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(PlusGold.gradient, in: shape)
            .overlay { shine }
            .overlay(alignment: .topTrailing) { sparkles }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .task(id: invites) { await play() }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
    }

    /// Çapraz ışık bandı; kutunun dışına taşmaz.
    private var shine: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.4, height: geo.size.height * 2)
            .rotationEffect(.degrees(20))
            .offset(x: sweep * geo.size.width * 1.1 + geo.size.width * 0.3, y: -geo.size.height / 2)
        }
        .clipShape(shape)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Köşede iki küçük yıldız: ışıkla birlikte belirip söner.
    private var sparkles: some View {
        ZStack(alignment: .topTrailing) {
            twinkleStar(size: 11, delay: 0.3).offset(x: -12, y: 10)
            twinkleStar(size: 7, delay: 0.45).offset(x: -26, y: 22)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func twinkleStar(size: CGFloat, delay: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.white)
            .keyframeAnimator(initialValue: 0.0, trigger: twinkle) { star, amount in
                star.scaleEffect(amount).opacity(amount)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: delay)
                    CubicKeyframe(1, duration: 0.2)
                    CubicKeyframe(0, duration: 0.45)
                }
            }
    }

    private func play() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(0.8))
        repeat {
            guard !Task.isCancelled else { return }
            if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { sweep = -1 }
                try? await Task.sleep(for: .milliseconds(30))
                withAnimation(.easeInOut(duration: 1.0)) { sweep = 1 }
                twinkle += 1
            }
            try? await Task.sleep(for: .seconds(4.5))
        } while invites
    }
}

private struct PlusTwist {
    var angle: Double = 0
    var scale: CGFloat = 1
}
