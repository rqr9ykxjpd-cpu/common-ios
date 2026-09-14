import SwiftUI

struct ScreenFailureView: View {
    let message: String
    var compact = false
    let retry: () -> Void

    var body: some View {
        VStack(alignment: compact ? .leading : .center, spacing: 12) {
            Label(L10n.Errors.title, systemImage: "wifi.exclamationmark").font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(compact ? .leading : .center)
            Button(L10n.Common.retry, action: retry)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
        }
        .foregroundStyle(BondTheme.ink)
        .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
        .padding(.vertical, compact ? 8 : 24)
        .accessibilityElement(children: .contain)
    }
}
