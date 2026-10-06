import SwiftUI

/// Common hesabının gönderisi akışta çerçeveli: ince kurucu rengi bir kenar,
/// üstünde kenar boyunca yavaşça dolaşan bir ışık. Parlama, bulanıklık yok;
/// hareketi azalt açıkken ışık durur, kenar kalır.
struct OfficialPostFrame: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bir tur süresi. Göz yakalasın ama okumayı bölmesin.
    private let period: TimeInterval = 6

    func body(content: Content) -> some View {
        if active {
            content
                .padding(.vertical, 16)
                .background { frame.padding(.horizontal, 8) }
        } else {
            content
        }
    }

    private var frame: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return ZStack {
            shape.strokeBorder(BondTheme.ember.opacity(0.22), lineWidth: 1)
            // Görünmeyen kart (tembel listede ekrandan çıkan) çizilmiyor; saat de duruyor.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let angle = Angle.degrees(t.truncatingRemainder(dividingBy: period) / period * 360)
                shape.strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: BondTheme.ember.opacity(0), location: 0),
                            .init(color: BondTheme.ember, location: 0.1),
                            .init(color: BondTheme.ember.opacity(0), location: 0.22),
                            .init(color: BondTheme.ember.opacity(0), location: 0.5),
                            .init(color: BondTheme.ember, location: 0.6),
                            .init(color: BondTheme.ember.opacity(0), location: 0.72),
                            .init(color: BondTheme.ember.opacity(0), location: 1)
                        ],
                        center: .center,
                        angle: angle
                    ),
                    lineWidth: 1.5
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
