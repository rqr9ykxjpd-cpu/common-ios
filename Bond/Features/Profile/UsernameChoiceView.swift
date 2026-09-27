import SwiftUI

/// Kullanıcı adı ekranı, iki yerden açılıyor:
/// - `.prompt`: kullanıcı adı otomatik verilmiş hesaplara (eski hesaplar,
///   Build 5 ile açılanlar) bir kez. Mevcut ad hazır dolu; onaylanır ya da değiştirilir.
/// - `.change`: Ayarlar → Hesabın → Kullanıcı adı.
struct UsernameChoiceView: View {
    enum Mode { case prompt, change }
    var mode: Mode = .prompt

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var status: UsernameStatus = .idle

    /// Değiştirme ekranında aynı adı "kaydetmek" anlamsız; düğme kapalı kalır.
    private var canSave: Bool {
        status.allowsSave && (mode == .prompt || username != appState.draft.username)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
            VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                Text(mode == .prompt ? L10n.Username.chooseTitle : L10n.AccountSettings.changeTitle)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .tracking(-0.4)
                    .accessibilityAddTraits(.isHeader)
                Text(mode == .prompt ? L10n.Username.chooseBody : L10n.AccountSettings.changeBody)
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
                enabled: canSave,
                action: { await appState.chooseUsername(username) },
                // ✓ görünsün diye ekran işlem bitince değil, ✓'den sonra kapanıyor.
                onDone: {
                    if mode == .prompt { appState.needsUsernameChoice = false } else { dismiss() }
                }
            )
            .accessibilityIdentifier("usernameChoice.save")
        }
        .padding(BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.md)
        .background(BondTheme.paper.ignoresSafeArea())
        .foregroundStyle(BondTheme.ink)
        // İlk kez sorulduğunda geçilemesin; değiştirirken aşağı çekip vazgeçilebilir.
        .interactiveDismissDisabled(mode == .prompt)
        .onAppear {
            if username.isEmpty {
                username = appState.draft.username.isEmpty
                    ? Username.suggestion(from: appState.draft.name)
                    : appState.draft.username
            }
        }
    }
}
