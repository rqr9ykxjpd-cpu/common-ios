import SwiftUI

/// Kurucu: Kullanıcılar listesinden seçilen kişiye tek bildirim.
struct FounderNotifySheet: View {
    let user: FounderUser
    let done: (Bool) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var sending = false
    @State private var failure: String?
    @FocusState private var titleFocused: Bool

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !cleanTitle.isEmpty && title.count <= 80 && message.count <= 300 && !sending }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.FounderNotify.titlePlaceholder, text: $title)
                        .focused($titleFocused)
                        .font(.headline)
                    TextField(L10n.FounderNotify.bodyPlaceholder, text: $message, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text(L10n.FounderNotify.hint(user.name))
                }
                if let failure {
                    Section {
                        Label(failure, systemImage: "exclamationmark.circle")
                            .font(.footnote)
                            .foregroundStyle(BondTheme.burntOrangeText)
                    }
                }
            }
            .navigationTitle(L10n.FounderNotify.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if sending {
                        ProgressView()
                    } else {
                        Button(L10n.FounderNotify.send) { Task { await send() } }
                            .disabled(!canSend)
                    }
                }
            }
            .onAppear { titleFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func send() async {
        guard canSend else { return }
        sending = true
        defer { sending = false }
        failure = nil
        do {
            try await appState.founderNotifyUser(user.id, title: cleanTitle,
                                                 body: message.trimmingCharacters(in: .whitespacesAndNewlines))
            Haptics.success()
            done(true)
            dismiss()
        } catch {
            failure = UserFacingError.message(error, fallback: L10n.FounderNotify.failed)
        }
    }
}
