import Foundation

// MARK: - AppState+FounderNotify
extension AppState {
    func founderNotifyUser(_ userID: UUID, title: String, body: String) async throws {
        guard let masa = service as? any FounderNotifying else { throw BackendServiceError.missingSession }
        try await masa.notifyUser(userID, title: title, body: body)
    }
}
