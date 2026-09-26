import SwiftUI

/// Bir ekranın içeriği yüklenemediğinde, içeriğin yerinde duran hata.
/// Modal uyarı yerine bu: kullanıcı neyin gelmediğini yerinde görür ve
/// "Tekrar dene" ile yalnızca o bölümü yeniler.
struct ScreenFailureView: View {
    var title: String = L10n.Errors.title
    let message: String
    var compact = false
    let retry: () -> Void

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: 12) {
            Label(title, systemImage: "wifi.exclamationmark").font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(compact ? .leading : .center)
            Button(L10n.Common.retry, action: retry)
                .buttonStyle(.bordered)
                .tint(BondTheme.ink)
                .frame(minHeight: 44)
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
        .padding(.vertical, compact ? 8 : 24)
        .accessibilityElement(children: .contain)
    }
}
