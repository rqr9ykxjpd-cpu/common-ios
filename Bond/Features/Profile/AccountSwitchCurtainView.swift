import SwiftUI

/// Hesap geçerken ekranı örter: kulübün logosu ya da kişi simgesi, nereye
/// geçildiği ve bekleme göstergesi.
struct AccountSwitchCurtainView: View {
    let curtain: AccountSwitchCurtain

    var body: some View {
        ZStack {
            BondTheme.paper.ignoresSafeArea()
            VStack(spacing: BondTheme.Space.md) {
                if let club = curtain.club {
                    ClubLogoView(url: curtain.logoURL, icon: club.icon, accentHex: club.accentHex, size: 72)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(BondTheme.ink)
                }
                Text(curtain.club.map { L10n.ClubSwitch.switchingTo($0.name) } ?? L10n.ClubSwitch.switchingBack)
                    .font(.headline)
                    .foregroundStyle(BondTheme.ink)
                    .multilineTextAlignment(.center)
                ProgressView()
                    .padding(.top, BondTheme.Space.sm)
            }
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
