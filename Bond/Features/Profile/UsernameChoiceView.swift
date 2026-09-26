import SwiftUI

/// "Kullanıcı adını seç": kullanıcı adı otomatik verilmiş hesaplara (eski
/// hesaplar, Build 5 ile açılanlar) bir kez gösteriliyor. Önerilen ad hazır
/// dolu gelir; tek dokunuşla onaylanır ya da değiştirilir.
struct UsernameChoiceView: View {
    @Environment(AppState.self) private var appState
    @State private var username = ""
    @State private var status: UsernameStatus = .idle
    @State private var saving = false

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

            Button {
                Task {
                    saving = true
                    _ = await appState.chooseUsername(username)
                    saving = false
                }
            } label: {
                HStack(spacing: 8) {
                    if saving { ProgressView().tint(BondTheme.onAccent) }
                    Text(L10n.Common.save).fontWeight(.semibold)
                }
                .foregroundStyle(BondTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(BondTheme.acid, in: Capsule())
            }
            .buttonStyle(.pressable)
            .disabled(!status.allowsSave || saving)
            .opacity(status.allowsSave ? 1 : 0.45)
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
