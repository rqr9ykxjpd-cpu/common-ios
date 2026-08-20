import SwiftUI

/// "Bu özellik Pro'ya özel" notu.
///
/// Ayrı bir satış ekranı değil, kısa bir açıklama: Pro henüz satışta değil.
/// Özelliğin varlığını göstermek, kilidi tamamen gizlemekten iyi — kimse
/// görmediği bir şeyi merak etmez.
struct ProUpsellSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CampusTheme.canvasDark.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("COMMON PRO")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(CampusTheme.acid)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Kapat")
                }

                Text("Kimin kaç kez\nizlediğini görmek.")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineSpacing(1)

                Text("Bunun için daha özel kullanıcılarımızdan olman gerekiyor. Pro yakında.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(3)

                Text("söz, sana ilk biz haber vereceğiz ☺")
                    .font(.custom("BradleyHandITCTT-Bold", size: 17))
                    .foregroundStyle(CampusTheme.acid.opacity(0.85))
                    .rotationEffect(.degrees(-1.5))
                    .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}
