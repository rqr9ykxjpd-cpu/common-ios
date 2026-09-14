import AuthenticationServices
import CryptoKit
import SwiftUI

/// TN3194: revoke with a fresh code when available, but never refuse account
/// deletion solely because an old token is missing or Apple cannot be reached.
struct AppleAccountDeletionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var nonce: String?
    @State private var isWorking = false
    @State private var appleWasRevoked = false
    @State private var statusMessage: String?
    @State private var showManualConfirmation = false

    private var isBusy: Bool { isWorking || appState.isAccountActionInProgress }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.Profile.deleteBody)
                    Text(L10n.AccountDeletion.subscriptionReminder)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if appleWasRevoked {
                        Text(L10n.AccountDeletion.revokedRetryBody)
                        Button(L10n.Profile.deleteAccount, role: .destructive) {
                            Task { await finishDeletion(manual: false) }
                        }
                        .disabled(isBusy)
                        Button(L10n.Profile.signOut) {
                            Task {
                                isWorking = true
                                await appState.signOut()
                                isWorking = false
                            }
                        }
                        .disabled(isBusy)
                    } else {
                        Text(L10n.AccountDeletion.reauthorizeBody)
                        SignInWithAppleButton(.continue) { request in
                            let newNonce = (0..<32).map { _ in
                                String(format: "%02x", UInt8.random(in: .min ... .max))
                            }.joined()
                            nonce = newNonce
                            request.nonce = SHA256.hash(data: Data(newNonce.utf8))
                                .map { String(format: "%02x", $0) }.joined()
                            request.requestedScopes = []
                            statusMessage = nil
                            isWorking = true
                        } onCompletion: { result in
                            completeAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 50)
                        .disabled(isBusy)
                    }

                    if isBusy {
                        HStack {
                            ProgressView()
                            Text(L10n.Profile.accountBusy)
                        }
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }

                if !appleWasRevoked {
                    Section {
                        Text(L10n.AccountDeletion.manualBody)
                        Link(L10n.AccountDeletion.appleInstructions,
                             destination: AppleAccountDeletionNotice.instructionsURL)
                        Button(L10n.AccountDeletion.manualDelete, role: .destructive) {
                            showManualConfirmation = true
                        }
                        .disabled(isBusy)
                    }
                }
            }
            .navigationTitle(L10n.Profile.deleteAccount)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                appleWasRevoked = appState.hasPendingAppleRevokedDeletion
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .disabled(isBusy || appleWasRevoked)
                }
            }
            .interactiveDismissDisabled(isBusy || appleWasRevoked)
            .alert(L10n.Profile.deleteConfirm, isPresented: $showManualConfirmation) {
                Button(L10n.Common.cancel, role: .cancel) {}
                Button(L10n.Profile.deleteAccount, role: .destructive) {
                    Task { await finishDeletion(manual: true) }
                }
            } message: {
                Text(L10n.AccountDeletion.manualConfirmBody)
            }
        }
    }

    private func completeAuthorization(_ result: Result<ASAuthorization, Error>) {
        let requestNonce = nonce
        nonce = nil
        switch result {
        case .failure(let error):
            isWorking = false
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                statusMessage = L10n.AccountDeletion.cancelled
            } else {
                statusMessage = L10n.AccountDeletion.revokeFailed
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = credential.authorizationCode,
                  let code = String(data: codeData, encoding: .utf8), !code.isEmpty,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8), !token.isEmpty,
                  let requestNonce else {
                isWorking = false
                statusMessage = L10n.AccountDeletion.revokeFailed
                return
            }
            Task {
                do {
                    try await appState.revokeAppleAuthorization(.init(
                        authorizationCode: code, identityToken: token, nonce: requestNonce
                    ))
                    appleWasRevoked = true
                    await finishDeletion(manual: false)
                } catch {
                    isWorking = false
                    if case AppleAccountRevocationError.accountMismatch = error {
                        statusMessage = L10n.AccountDeletion.wrongAppleAccount
                    } else {
                        statusMessage = L10n.AccountDeletion.revokeFailed
                    }
                }
            }
        }
    }

    private func finishDeletion(manual: Bool) async {
        isWorking = true
        let deleted = await appState.deleteAccount(manualAppleRevocation: manual)
        isWorking = false
        if deleted {
            dismiss()
        } else {
            statusMessage = L10n.Auth.deleteFailed
        }
    }
}
