import SwiftUI

/// Hesap dondurulunca uygulamanın yerine bu ekran açılır: ne olduğu, itiraz
/// için destek yazışması, çıkış ve hesabı silme (Apple, silmenin uygulama
/// içinden yapılabilmesini istiyor; dondurulan kişi için de geçerli).
struct FrozenAccountView: View {
    @Environment(AppState.self) private var appState
    @State private var showSupport = false
    @State private var showDeleteAlert = false
    @State private var showAppleDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
            Spacer(minLength: BondTheme.Space.xxl)

            VStack(alignment: .leading, spacing: BondTheme.Space.md) {
                Text(L10n.FrozenAccount.title)
                    .editorialTitle(36)
                    .foregroundStyle(BondTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.FrozenAccount.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.FrozenAccount.appeal)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: BondTheme.Space.sm) {
                Button { showSupport = true } label: {
                    Text(L10n.FrozenAccount.contact)
                        .font(.headline)
                        .foregroundStyle(BondTheme.paper)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(BondTheme.ink, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("frozen.support")

                Button {
                    Task { await appState.signOut() }
                } label: {
                    Text(L10n.Profile.signOut)
                        .font(.headline)
                        .foregroundStyle(BondTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(BondTheme.surface, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(appState.isAccountActionInProgress)

                Button(L10n.Profile.deletePermanent, role: .destructive) {
                    if appState.hasAppleIdentity { showAppleDelete = true } else { showDeleteAlert = true }
                }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
                .disabled(appState.isAccountActionInProgress)
            }
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.bottom, BondTheme.Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(BondTheme.paper.ignoresSafeArea())
        .sheet(isPresented: $showSupport) {
            SupportInboxView()
        }
        .sheet(isPresented: $showAppleDelete) {
            AppleAccountDeletionView()
        }
        .alert(L10n.Profile.deleteConfirm, isPresented: $showDeleteAlert) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Profile.deleteAccount, role: .destructive) {
                Task { await appState.deleteAccount() }
            }
        } message: {
            Text(L10n.Profile.deleteBody)
        }
    }
}
