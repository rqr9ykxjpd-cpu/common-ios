import SwiftUI

struct MessageRequestComposer: View {
    let profile: StudentProfile
    let onSent: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false
    @State private var failed = false

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(profile.name).font(.headline)
                    Text(L10n.CampusDesign.requestHint).foregroundStyle(.secondary)
                }
                Section {
                    TextField(L10n.CampusDesign.requestPlaceholder, text: $message, axis: .vertical)
                        .lineLimit(5...10)
                        .onChange(of: message) { _, value in
                            if value.count > 500 { message = String(value.prefix(500)) }
                        }
                    Text("\(message.count)/500").font(.caption).foregroundStyle(.secondary)
                }
                if failed {
                    Section { Text(L10n.CampusDesign.requestFailure).foregroundStyle(BondTheme.coral) }
                }
            }
            .navigationTitle(L10n.CampusDesign.requestTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSending = true
                        failed = false
                        Task {
                            let sent = await appState.sendMessageRequest(to: profile, body: trimmed)
                            isSending = false
                            if sent { onSent(); dismiss() } else { failed = true }
                        }
                    } label: {
                        if isSending { ProgressView() }
                        else { Image(systemName: "paperplane") }
                    }
                    .accessibilityLabel(L10n.CampusDesign.requestCTA)
                    .disabled(trimmed.isEmpty || isSending)
                }
            }
            .interactiveDismissDisabled(isSending)
        }
    }
}
