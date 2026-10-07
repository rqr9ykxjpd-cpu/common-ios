import SwiftUI

/// Common hesabının gönderisi akışta çerçeveli: mavi, mor, pembe ve turuncu
/// arasında akan renkli bir kenar, arkasında aynı renklerin yumuşak ışığı.
/// Renkler kenar boyunca yavaşça döner. Hareketi azalt açıkken renkler durur,
/// çerçeve kalır.
struct OfficialPostFrame: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Bir tur süresi. Göz yakalasın ama okumayı bölmesin.
    private let period: TimeInterval = 8

    private static let colors: [Color] = [
        Color(hex: "4285F4"),
        Color(hex: "9B72CB"),
        Color(hex: "D96570"),
        Color(hex: "F4A261"),
        Color(hex: "9B72CB"),
        Color(hex: "4285F4")
    ]

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
        // Görünmeyen kart (tembel listede ekrandan çıkan) çizilmiyor; saat de duruyor.
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees(t.truncatingRemainder(dividingBy: period) / period * 360)
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: angle)
            ZStack {
                // Kartın içi çok hafif renk alır; yazı okunurluğu bozulmasın.
                shape.fill(gradient.opacity(colorScheme == .dark ? 0.07 : 0.05))
                // Yumuşak ışık: kenarın bulanık kopyası, dışa taşar.
                shape
                    .strokeBorder(gradient, lineWidth: 6)
                    .blur(radius: 10)
                    .opacity(colorScheme == .dark ? 0.55 : 0.4)
                shape.strokeBorder(gradient, lineWidth: 1.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
