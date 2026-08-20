import SwiftUI

/// Rozetin tek gösterim biçimi.
///
/// Rozet önce her ekranda ayrı ayrı çiziliyordu ve çoğu yerde çıplak bir ikondu:
/// yıldızı gören "bu ne demek" diye soruyordu. Üstelik her yeni ekranda yeniden
/// yazıldığı için biçimler birbirinden ayrışıyordu. Tek bileşene bağlandı.
struct ProfileBadgeLabel: View {
    let badge: ProfileBadge
    /// Dar yerlerde (akış başlığı, liste satırı) daha küçük durur.
    var compact = false

    var body: some View {
        if let icon = badge.systemImage, let title = badge.title {
            Label(title, systemImage: icon)
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(CampusTheme.ink)
                .padding(.horizontal, compact ? 8 : 10)
                .frame(height: compact ? 22 : 26)
                .background(CampusTheme.acid, in: Capsule())
                .lineLimit(1)
                .fixedSize()
        }
    }
}
