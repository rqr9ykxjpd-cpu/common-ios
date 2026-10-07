import SwiftUI

/// Resmi Common hesabının mavi tiki; yalnızca bu hesapta. Diğer doğrulanmış
/// hesaplar uygulamanın siyah-beyaz tikini taşır (`VerifiedTick`).
struct OfficialTick: View {
    var size: CGFloat = 16

    static let blue = Color(hex: "1D9BF0")

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Self.blue)
            .accessibilityElement()
            .accessibilityLabel(L10n.Official.line)
    }
}
