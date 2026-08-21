import Foundation

extension L10n {
    enum Errors {
        static var configMissing: String { String(localized: "error.configMissing") }
        static var missingSession: String { String(localized: "error.missingSession") }
        static var incompleteProfile: String { String(localized: "error.incompleteProfile") }
        static var offline: String { String(localized: "error.offline") }
        static var timedOut: String { String(localized: "error.timedOut") }
        static var connectionLost: String { String(localized: "error.connectionLost") }
        static var hostUnreachable: String { String(localized: "error.hostUnreachable") }
        static var dataNotAllowed: String { String(localized: "error.dataNotAllowed") }
        static var secureFailed: String { String(localized: "error.secureFailed") }
        static var clockSkew: String { String(localized: "error.clockSkew") }
        static var nonce: String { String(localized: "error.nonce") }
        static var providerDisabled: String { String(localized: "error.providerDisabled") }
        static var oauthState: String { String(localized: "error.oauthState") }
        static var invalidToken: String { String(localized: "error.invalidToken") }
        static var emailTaken: String { String(localized: "error.emailTaken") }
        static var banned: String { String(localized: "error.banned") }
        static var signupDisabled: String { String(localized: "error.signupDisabled") }
        static var rateLimit: String { String(localized: "error.rateLimit") }
        static var sessionExpired: String { String(localized: "error.sessionExpired") }
        static var minInterests: String { String(localized: "error.minInterests") }
        static var permission: String { String(localized: "error.permission") }
        static var duplicate: String { String(localized: "error.duplicate") }
        static var foreignKey: String { String(localized: "error.foreignKey") }
        static var tooLong: String { String(localized: "error.tooLong") }
        static var serverGap: String { String(localized: "error.serverGap") }
        static var fileTooLarge: String { String(localized: "error.fileTooLarge") }
        static var photoTooLarge: String { String(localized: "error.photoTooLarge") }
        static var bucketMissing: String { String(localized: "error.bucketMissing") }
        static var unavailable: String { String(localized: "error.unavailable") }
        static var timeout: String { String(localized: "error.timeout") }
        static var googleNotConfigured: String { String(localized: "error.googleNotConfigured") }
    }
}
