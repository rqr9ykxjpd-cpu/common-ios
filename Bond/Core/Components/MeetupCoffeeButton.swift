import SwiftUI

/// Buluşma isteği düğmesi: yazı yerine kahve fincanı.
///
/// "Buluşalım" metni listede iki satıra sarıyor, dar satırlarda ismin yerini
/// yiyordu. Fincan hem daha kısa hem de eylemi anlatıyor: kampüste biriyle
/// kahve içmeye çağırıyorsun. Dokununca fincandan buhar çıkar, ardından ikon
/// tike döner — istek gittiğini anlatan tek işaret bu.
struct MeetupCoffeeButton: View {
    /// İstek zaten gönderildiyse düğme tike döner ve kapanır.
    let sent: Bool
    var size: CGFloat = 46
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var steaming = false

    var body: some View {
        Button {
            guard !sent else { return }
            Haptics.success()
            if !reduceMotion {
                steaming = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { steaming = false }
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(sent ? BondTheme.ink : BondTheme.surface)
                    .overlay(Circle().strokeBorder(BondTheme.ink.opacity(sent ? 0 : 0.12), lineWidth: 1))

                Image(systemName: sent ? "checkmark" : "cup.and.saucer.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(sent ? BondTheme.paper : BondTheme.ink)
                    .contentTransition(.symbolEffect(.replace))

                if steaming { steam }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .disabled(sent)
        .animation(reduceMotion ? nil : BondTheme.Motion.bouncy, value: sent)
    }

    /// Fincanın üstünden yükselen üç ince buhar; sırayla çıkar, silinir.
    private var steam: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(BondTheme.muted.opacity(0.55))
                    .frame(width: 2.5, height: size * 0.22)
                    .offset(y: steaming ? -size * 0.55 : -size * 0.18)
                    .opacity(steaming ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 0.75).delay(Double(i) * 0.1),
                        value: steaming
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
