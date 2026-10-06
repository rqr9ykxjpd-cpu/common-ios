import SwiftUI

/// Ayarlar → "Arkadaşını davet et". Davet kodu yok: arkadaş kayıtta kullanıcı
/// adını yazıyor. Burada o ad, kaç kişinin katıldığı ve paylaşma düğmesi.
struct InviteFriendsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var username: String { appState.draft.username }

    private var shareText: String {
        L10n.Referral.shareMessage(username: username, link: AppLinks.appStore.absoluteString)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.Referral.headline)
                        .campusDisplay(30)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.Referral.body)
                        .font(BondTheme.Typography.body)
                        .foregroundStyle(BondTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, BondTheme.Space.sm)
                    if appState.tier == .pro {
                        Text(L10n.Referral.proNote)
                            .font(BondTheme.Typography.footnote)
                            .foregroundStyle(BondTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, BondTheme.Space.sm)
                    }

                    usernameRow
                        .padding(.top, BondTheme.Space.xl)

                    if let ozet = appState.referralSummary {
                        HStack(spacing: 0) {
                            stat(ozet.joined, L10n.Referral.joined)
                            stat(ozet.verified, L10n.Referral.verified)
                        }
                        .padding(.vertical, 16)
                        .overlay(alignment: .top) { hairline }
                        .transition(.opacity)
                    }

                    ShareLink(item: shareText) {
                        Label(L10n.Referral.share, systemImage: "square.and.arrow.up")
                            .font(BondTheme.Typography.body.weight(.semibold))
                            .foregroundStyle(BondTheme.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(BondTheme.acid, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(username.isEmpty)
                    .padding(.top, BondTheme.Space.xl)
                }
                .padding(.horizontal, BondTheme.Space.lg)
                .padding(.vertical, BondTheme.Space.lg)
                .animation(.smooth(duration: 0.25), value: appState.referralSummary)
            }
            .background(BondTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.Referral.rowTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .task { await appState.loadReferralSummary() }
        }
    }

    /// Kullanıcı adı ve kopyala. Arkadaş bunu kayıtta yazacak.
    private var usernameRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Referral.yourUsername)
                    .font(BondTheme.Typography.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(BondTheme.muted)
                Text("@" + username)
                    .campusHeading(26)
                    .foregroundStyle(BondTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
            }
            Spacer(minLength: BondTheme.Space.md)
            Button {
                UIPasteboard.general.string = username
                Haptics.selection()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    copied = false
                }
            } label: {
                Text(copied ? L10n.Referral.copied : L10n.Referral.copy)
                    .font(BondTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(BondTheme.surface, in: Capsule())
                    .contentTransition(.opacity)
            }
            .buttonStyle(PressableStyle())
            .disabled(username.isEmpty)
            .animation(.smooth(duration: 0.2), value: copied)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { hairline }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .campusHeading(26)
                .foregroundStyle(BondTheme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(BondTheme.Typography.footnote)
                .foregroundStyle(BondTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var hairline: some View {
        Rectangle()
            .fill(BondTheme.hairline.opacity(0.8))
            .frame(height: 0.5)
    }
}
