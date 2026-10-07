import SwiftUI

/// Common hesabının gönderisi akışta Gemini / Siri ışığı gibi: kart düz
/// zeminde durur, etrafını mavi, mor, kırmızı ve turuncu arasında akan
/// yumuşak bir ışık sarar. Renkler kartın çevresinde döner, ışık nefes alır.
/// Hareketi azalt açıkken ışık durur.
struct OfficialPostFrame: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// Renklerin kart etrafında bir tur dönmesi.
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

    func body(content: Content) -> some View {
        if active {
            // Kart ekran kenarından içeride; dört yanda ışığa yer var
            // (gönderinin sınırında kesilmesin).
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 18)
                .background { card.padding(.horizontal, 14) }
                .padding(.vertical, 44)
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
                let aci = Angle.degrees(t.truncatingRemainder(dividingBy: spin) / spin * 360)
                let nefes = (sin(t.truncatingRemainder(dividingBy: breath) / breath * 2 * .pi) + 1) / 2
                let renkler = AngularGradient(colors: Self.colors, center: .center, angle: aci)
                ZStack {
                    // Geniş, dağınık ışık.
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(renkler)
                        .padding(-8 - 4 * nefes)
                        .blur(radius: 24)
                        .opacity((colorScheme == .dark ? 0.55 : 0.5) + 0.2 * nefes)
                    // Kenara yakın, daha canlı ışık.
                    shape
                        .strokeBorder(renkler, lineWidth: 8)
                        .blur(radius: 8)
                        .opacity(colorScheme == .dark ? 0.8 : 0.7)
                }
            }
            shape.fill(BondTheme.paper)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
