import Foundation

/// A fresh, one-use Apple code. Never persist this payload or log its tokens.
struct AppleAccountRevocationRequest: Encodable, Sendable {
    let authorizationCode: String
    let identityToken: String
    let nonce: String
}

/// Kept separate from ProductService so offline/demo implementations cannot claim
/// they revoked an Apple authorization. The server verifies the actual identity.
protocol AppleAccountRevocationService: Sendable {
    var hasAppleIdentity: Bool { get }
    var appleSubject: String? { get }
    func revokeAppleAuthorization(_ request: AppleAccountRevocationRequest) async throws
}

enum AppleAccountRevocationError: LocalizedError {
    case unavailable
    case accountMismatch

    var errorDescription: String? {
        switch self {
        case .unavailable: L10n.AccountDeletion.revokeFailed
        case .accountMismatch: L10n.AccountDeletion.wrongAppleAccount
        }
    }
}

enum AppleAccountDeletionNotice {
    static let defaultsKey = "account.appleRevocationPending"
    static let revokedDeletionUserKey = "account.appleRevokedPendingDeletionUser"
    static let instructionsURL = URL(string: "https://support.apple.com/102571")!
}
