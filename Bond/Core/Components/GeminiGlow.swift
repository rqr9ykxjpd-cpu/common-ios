import SwiftUI

/// Gemini / Siri ışığı: şeklin çevresinde mavi, mor, kırmızı ve sarı arasında
/// dönen yumuşak ışık; ışık nefes alır. Hareketi azalt açıkken durur.
/// Common'un gönderisi (`OfficialPostFrame`) ve Kim nerede'deki Kulüpler düğmesi.
/// Kartın arkasına konur; kartın kendi zemini üstte olmalı.
struct GeminiGlow: View {
    let cornerRadius: CGFloat
    /// Işığın yayıldığı mesafe: gönderide 1, küçük düğmede daha az.
    var spread: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Renklerin şeklin etrafında bir tur dönmesi.
    private let spin: TimeInterval = 6
    /// Nefes.
    private let breath: TimeInterval = 4

    private static let colors: [Color] = [
        Color(hex: "4285F4"),
        Color(hex: "9B72CB"),
        Color(hex: "EA4335"),
        Color(hex: "FBBC04"),
        Color(hex: "4285F4")
    ]

    var body: some View {
        // Görünmeyen kart (tembel listede ekrandan çıkan) çizilmiyor; saat de duruyor.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let aci = Angle.degrees(t.truncatingRemainder(dividingBy: spin) / spin * 360)
            let nefes = (sin(t.truncatingRemainder(dividingBy: breath) / breath * 2 * .pi) + 1) / 2
            let renkler = AngularGradient(colors: Self.colors, center: .center, angle: aci)
            ZStack {
                // Geniş, dağınık ışık.
                RoundedRectangle(cornerRadius: cornerRadius + 8 * spread, style: .continuous)
                    .fill(renkler)
                    .padding((-8 - 4 * nefes) * spread)
                    .blur(radius: 24 * spread)
                    .opacity((colorScheme == .dark ? 0.55 : 0.5) + 0.2 * nefes)
                // Kenara yakın, daha canlı ışık.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(renkler, lineWidth: 8 * spread)
                    .blur(radius: 8 * spread)
                    .opacity(colorScheme == .dark ? 0.8 : 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
