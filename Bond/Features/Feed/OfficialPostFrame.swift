import SwiftUI

/// Common hesabının gönderisi akışta Gemini'deki gibi: kart düz zeminde durur,
/// arkasında kenarlarından dışa taşan yumuşak, dağınık bir ışık. Çizgi yok.
/// Işık mavi ağırlıklı; mor ve pembe tonlar yavaşça yer değiştirir, bütün
/// ışık hafifçe nefes alır. Hareketi azalt açıkken ışık durur.
struct OfficialPostFrame: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Nefes ve renk kayması süresi.
    private let period: TimeInterval = 6

    func body(content: Content) -> some View {
        if active {
            // Kart ekran kenarından içeride; ışık iki yanda da görünsün.
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 18)
                .background { card.padding(.horizontal, 14) }
        } else {
            content
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack {
            // Görünmeyen kart (tembel listede ekrandan çıkan) çizilmiyor; saat de duruyor.
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let faz = t.truncatingRemainder(dividingBy: period) / period * 2 * .pi
                let nefes = (sin(faz) + 1) / 2
                glow(nefes: nefes, kayma: cos(faz))
            }
            shape
                .fill(BondTheme.paper)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 10, y: 3)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Kartın arkasındaki ışık: büyük mavi bir hale, üstünde yer değiştiren
    /// mor ve pembe lekeler; hepsi bulanık ve kartın dışına taşar.
    private func glow(nefes: Double, kayma: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color(hex: "6EA8FE"))
                    .frame(width: w * 1.05, height: h * 1.05)
                Ellipse()
                    .fill(Color(hex: "A78BFA"))
                    .frame(width: w * 0.6, height: h * 0.5)
                    .offset(x: w * 0.22 * kayma, y: h * 0.18)
                Ellipse()
                    .fill(Color(hex: "F9A8D4"))
                    .frame(width: w * 0.45, height: h * 0.35)
                    .offset(x: -w * 0.2 * kayma, y: -h * 0.2)
            }
            .frame(width: w, height: h)
            .scaleEffect(x: 1 + 0.04 * nefes, y: 1 + 0.06 * nefes)
            .blur(radius: 28)
            .opacity((colorScheme == .dark ? 0.45 : 0.6) + 0.25 * nefes)
        }
        // Işık kartın dışına taşar.
        .padding(.horizontal, -12)
        .padding(.vertical, -22)
    }
}
