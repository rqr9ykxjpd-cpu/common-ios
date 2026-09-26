import SwiftUI

/// Bağlantı yokken ekranın üstünde duran ince şerit. Dokunulmaz, bir şey
/// istemez; yalnızca yüklenmeyen içeriğin sebebini söyler ve bağlantı
/// dönünce kendiliğinden kaybolur.
struct OfflineBanner: View {
    var body: some View {
        Label(L10n.Errors.offlineBanner, systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BondTheme.onAccent)
            .padding(.horizontal, BondTheme.Space.md)
            .padding(.vertical, BondTheme.Space.sm)
            .background(BondTheme.acid, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
}
