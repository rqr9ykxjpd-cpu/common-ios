import SwiftUI

/// "Kullanıcı adını seç": kullanıcı adı otomatik verilmiş hesaplara (eski
/// hesaplar, Build 5 ile açılanlar) bir kez gösteriliyor. Önerilen ad hazır
/// dolu gelir; tek dokunuşla onaylanır ya da değiştirilir.
struct UsernameChoiceView: View {
    @Environment(AppState.self) private var appState
    @State private var username = ""
    @State private var status: UsernameStatus = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                Text(L10n.Username.chooseTitle)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .tracking(-0.4)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.Username.chooseBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            UsernameField(text: $username, status: $status, check: { aday in
                try await appState.isUsernameAvailable(aday)
            }, autofocus: true)
            .padding(BondTheme.Space.md)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))

            Spacer(minLength: 0)

            PrimaryActionButton(
                title: L10n.Common.save,
                enabled: status.allowsSave,
                action: { await appState.chooseUsername(username) },
                // ✓ görünsün diye ekran işlem bitince değil, ✓'den sonra kapanıyor.
                onDone: { appState.needsUsernameChoice = false }
            )
            .accessibilityIdentifier("usernameChoice.save")
        }
        .padding(BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.md)
        .background(BondTheme.paper.ignoresSafeArea())
        .foregroundStyle(BondTheme.ink)
        .interactiveDismissDisabled()
        .onAppear {
            if username.isEmpty {
                username = appState.draft.username.isEmpty
                    ? Username.suggestion(from: appState.draft.name)
                    : appState.draft.username
            }
        }
    }
}
