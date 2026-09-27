import SwiftUI

/// "Sorun bildir": kullanıcı uygulamayla ilgili bir sorunu yazar; kurucu
/// Ayarlar → Şikâyetler → Sorunlar'da görür. Sürüm, iOS ve cihaz modeli
/// kendiliğinden eklenir (kişisel veri yok), kullanıcı bunu altta görür.
struct ProblemReportView: View {
    /// Nereden açıldı ("Profil", "Kayıt"); bildirime eklenir.
    let screen: String

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sending = false
    @FocusState private var focused: Bool

    private let maxLength = 2000
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { trimmed.count >= 3 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BondTheme.Space.lg) {
                VStack(alignment: .leading, spacing: BondTheme.Space.sm) {
                    Text(L10n.ProblemReport.title)
                        .font(.system(.title, design: .serif).weight(.bold))
                        .tracking(-0.4)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.ProblemReport.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L10n.ProblemReport.placeholder)
                            .font(.body)
                            .foregroundStyle(BondTheme.muted.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .onChange(of: text) { _, yeni in
                            if yeni.count > maxLength { text = String(yeni.prefix(maxLength)) }
                        }
                        .accessibilityLabel(L10n.ProblemReport.title)
                }
                .frame(minHeight: 150, maxHeight: 240)
                .padding(BondTheme.Space.compact)
                .background(BondTheme.surface, in: RoundedRectangle(cornerRadius: BondTheme.Radius.surface, style: .continuous))

                Text(L10n.ProblemReport.attached(ProblemReportContext.line(from: ProblemReportContext.current(screen: screen))))
                    .font(.caption)
                    .foregroundStyle(BondTheme.muted)

                Spacer(minLength: 0)

                PrimaryActionButton(
                    title: L10n.ProblemReport.send,
                    enabled: canSend,
                    action: { await send() },
                    onDone: { dismiss() }
                )
                .accessibilityIdentifier("problemReport.send")
            }
            .padding(BondTheme.Space.lg)
            .background(BondTheme.paper.ignoresSafeArea())
            .foregroundStyle(BondTheme.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                        .disabled(sending)
                }
            }
        }
        .interactiveDismissDisabled(sending || !trimmed.isEmpty)
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            focused = true
        }
    }

    private func send() async -> Bool {
        sending = true
        defer { sending = false }
        return await appState.reportProblem(trimmed, screen: screen)
    }
}
