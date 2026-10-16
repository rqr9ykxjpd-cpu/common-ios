import SwiftUI

/// Neden bildirim izni istendiği: cevap bekleyen bir şey yapıldığında açılan
/// kısa kart. Sistem penceresi "Bildirimleri aç"tan sonra geliyor.
enum PushAskReason: String, Identifiable {
    case message, connection, post, group, event

    var id: String { rawValue }

    var body: String {
        switch self {
        case .message: L10n.Engage.pushAskMessage
        case .connection: L10n.Engage.pushAskConnection
        case .post: L10n.Engage.pushAskPost
        case .group: L10n.Engage.pushAskGroup
        case .event: L10n.Engage.pushAskEvent
        }
    }
}

struct PushAskView: View {
    @Environment(AppState.self) private var appState
    let reason: PushAskReason
    @State private var bellRang = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BondTheme.Space.md) {
            Image(systemName: "bell.badge")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(BondTheme.ink)
                .frame(width: 52, height: 52)
                .background(BondTheme.surface, in: Circle())
                .symbolEffect(.wiggle, options: .nonRepeating, value: bellRang)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Engage.pushAskTitle)
                    .campusHeading(24)
                    .foregroundStyle(BondTheme.ink)
                Text(reason.body)
                    .font(BondTheme.Typography.body)
                    .foregroundStyle(BondTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: BondTheme.Space.sm) {
                Button { appState.acceptPushAsk() } label: {
                    Text(L10n.Engage.pushAskAllow)
                        .font(BondTheme.Typography.body.weight(.semibold))
                        .foregroundStyle(BondTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(BondTheme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("pushAsk.allow")

                Button { appState.pushAsk = nil } label: {
                    Text(L10n.Engage.pushAskLater)
                        .font(BondTheme.Typography.body.weight(.medium))
                        .foregroundStyle(BondTheme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("pushAsk.later")
            }
            .padding(.top, BondTheme.Space.sm)
        }
        .padding(.horizontal, BondTheme.Space.lg)
        .padding(.top, BondTheme.Space.xl)
        .padding(.bottom, BondTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BondTheme.paper.ignoresSafeArea())
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(0.35))
            bellRang += 1
        }
    }
}

/// Sohbet'in üstünde: bildirimler kapalıysa ya da hiç sorulmadıysa. Kapalıysa
/// Ayarlar'a, hiç sorulmadıysa sistem penceresine götürür.
struct PushOffCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: BondTheme.Space.compact) {
            Image(systemName: "bell.slash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BondTheme.ink)
                .frame(width: 40, height: 40)
                .background(BondTheme.paper, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Engage.pushOffTitle)
                    .font(BondTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(BondTheme.ink)
                Text(L10n.Engage.pushOffBody)
                    .font(BondTheme.Typography.footnote)
                    .foregroundStyle(BondTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(L10n.Engage.pushOffAction) {
                if appState.pushStatus == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    appState.acceptPushAsk()
                }
            }
            .font(BondTheme.Typography.footnote.weight(.semibold))
            .foregroundStyle(BondTheme.onAccent)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(BondTheme.ink, in: Capsule())
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("chats.pushOn")
        }
        .padding(BondTheme.Space.compact)
        .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        .contextMenu {
            Button(L10n.Engage.pushOffDismiss, systemImage: "eye.slash") { appState.hidePushOffCard() }
        }
        .accessibilityAction(named: L10n.Engage.pushOffDismiss) { appState.hidePushOffCard() }
    }
}

/// Davet satırı: profilde ve Sohbet'in sonunda. Doğrulayan her arkadaş için
/// 1 hafta Plus; özellik vardı ama ayarların içinde kalmıştı (15 Ekim: 0 davet).
struct InviteRow: View {
    var title: String = L10n.Referral.rowTitle
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: BondTheme.Space.compact) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BondTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(BondTheme.paper, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BondTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(BondTheme.ink)
                    Text(L10n.Referral.rowHint)
                        .font(BondTheme.Typography.footnote)
                        .foregroundStyle(BondTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BondTheme.muted)
                    .accessibilityHidden(true)
            }
            .padding(BondTheme.Space.compact)
            .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("invite.row")
    }
}
