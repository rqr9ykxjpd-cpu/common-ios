import SwiftUI

/// Common hesabının gönderisi akışta Gemini / Siri ışığı gibi: kart düz
/// zeminde durur, etrafını mavi, mor, kırmızı ve turuncu arasında akan
/// yumuşak bir ışık sarar (`GeminiGlow`).
struct OfficialPostFrame: ViewModifier {
    let active: Bool

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
            GeminiGlow(cornerRadius: 22)
            shape.fill(BondTheme.paper)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
