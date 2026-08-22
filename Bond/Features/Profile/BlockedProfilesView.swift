import SwiftUI

/// Engellediğin kişiler ve engeli kaldırma.
///
/// Engelleme, gönderi ve profil menülerinde şikayet etmenin hemen yanında
/// duruyor — yanlışlıkla basmak kolay. Buraya kadar geri alınabilir bir yolu
/// yoktu: `unblockUser` sunucuda yazılıydı ama onu çağıran tek bir düğme
/// bulunmuyordu, yani engelleme tek yönlü bir kapıydı.
struct BlockedProfilesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var islemdeki: UUID?

    var body: some View {
        List {
            if appState.blockedProfiles.isEmpty {
                ContentUnavailableView(
                    L10n.Profile.blockedEmpty,
                    systemImage: "hand.raised",
                    description: Text(L10n.Profile.blockedEmptyHint)
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(appState.blockedProfiles) { kisi in
                    satir(kisi)
                }
            }
        }
        .navigationTitle(L10n.Profile.blocked)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Common.close) { dismiss() }
            }
        }
        .task { await appState.loadBlockedProfiles() }
        .refreshable { await appState.loadBlockedProfiles() }
    }

    private func satir(_ kisi: BlockedProfile) -> some View {
        let calisiyor = islemdeki == kisi.id
        return HStack(spacing: BondTheme.Space.md) {
            ProfileMedia(url: kisi.imageURL, data: nil)
                .frame(width: 42, height: 42)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                // Adı okunamayan kayıtlar da listede kalıyor: kimliği
                // görememek, engeli kaldıramamak için sebep değil.
                Text(kisi.name ?? L10n.Profile.blockedUnknown)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kisi.name == nil ? BondTheme.muted : BondTheme.ink)
                Text(kisi.blockedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 12))
                    .foregroundStyle(BondTheme.muted)
            }

            Spacer(minLength: 0)

            Button {
                islemdeki = kisi.id
                Task {
                    await appState.unblock(kisi.id)
                    islemdeki = nil
                }
            } label: {
                if calisiyor {
                    ProgressView()
                } else {
                    Text(L10n.Profile.unblock)
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .buttonStyle(.bordered)
            .disabled(calisiyor)
        }
        .padding(.vertical, 4)
    }
}
