import SwiftUI

/// "Bekleyen istek" kartının görünümü. Profildeki (bağlantı, mesaj, buluşma)
/// ve Sohbet'teki (mesaj istekleri) kartlar eskiden iki ayrı tasarımdı; aynı
/// şeyi anlatan iki kart artık aynı görünüyor. Düğme ya da bağlantı çağıranın.
struct RequestSummaryLabel: View {
    let title: String
    let detail: String
    /// Bekleyen varsa turuncu vurgu; yoksa sakin yüzey.
    var active: Bool = true

    var body: some View {
        HStack(spacing: BondTheme.Space.compact) {
            Image(systemName: active ? "tray.full.fill" : "tray")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(active ? BondTheme.onAccent : BondTheme.ink)
                .frame(width: 40, height: 40)
                .background(active ? BondTheme.burntOrange : BondTheme.paper, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: BondTheme.Space.sm)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BondTheme.muted)
                .accessibilityHidden(true)
        }
        .foregroundStyle(BondTheme.ink)
        .padding(.horizontal, BondTheme.Space.md)
        .frame(maxWidth: .infinity, minHeight: active ? 76 : 64, alignment: .leading)
        .background(
            active ? BondTheme.burntOrange.opacity(0.10) : BondTheme.surface,
            in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
