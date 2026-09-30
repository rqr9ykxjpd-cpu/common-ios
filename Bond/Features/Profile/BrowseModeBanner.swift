import SwiftUI

/// Akışın başındaki ince şerit: doğrulanmamış öğrenci gezinti modunda.
/// Bağlantı gönderildiyse "e-postanı kontrol et" der. Dokununca doğrulama
/// penceresi açılır.
struct BrowseModeBanner: View {
    @Environment(AppState.self) private var appState

    private var pending: Bool { appState.eduStatus?.isPending == true }

    var body: some View {
        Button { appState.presentEduGate(.none) } label: {
            HStack(spacing: 8) {
                Image(systemName: pending ? "envelope.badge" : "eye")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(pending ? L10n.Edu.pendingTitle : L10n.Support.browseBanner)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(L10n.Support.browseAction)
                    .font(.footnote.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(BondTheme.burntOrangeText)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(BondTheme.burntOrange.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("feed.browseMode")
    }
}
