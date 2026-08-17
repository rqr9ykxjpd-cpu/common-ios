import Foundation

protocol ProductService: Sendable {
    var isDemo: Bool { get }
    var currentUserID: UUID? { get }

    func requestOTP(email: String) async throws
    func verifyOTP(email: String, code: String) async throws
    func restoreSession() async throws -> UUID?
    func signOut() async throws
    func saveProfile(_ draft: ProfileDraft) async throws
    func fetchFeed() async throws -> [BackendPost]
    func createPost(caption: String, placeName: String?) async throws -> BackendPost
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment
    func deletePost(_ postID: UUID) async throws
    func deleteComment(_ commentID: UUID) async throws
    func recordReaction(profileID: UUID, liked: Bool) async
    func send(_ message: Message, conversationID: UUID) async
}

struct DemoProductService: ProductService {
    let isDemo = true
    var currentUserID: UUID? { nil }

    func requestOTP(email: String) async throws {
        try await Task.sleep(for: .milliseconds(350))
    }

    func verifyOTP(email: String, code: String) async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    func restoreSession() async throws -> UUID? { nil }
    func signOut() async throws {}
    func saveProfile(_ draft: ProfileDraft) async throws {}
    func fetchFeed() async throws -> [BackendPost] { [] }
    func createPost(caption: String, placeName: String?) async throws -> BackendPost {
        throw BackendServiceError.missingConfiguration
    }
    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        throw BackendServiceError.missingConfiguration
    }
    func deletePost(_ postID: UUID) async throws {}
    func deleteComment(_ commentID: UUID) async throws {}

    func recordReaction(profileID: UUID, liked: Bool) async {
        try? await Task.sleep(for: .milliseconds(120))
    }

    func send(_ message: Message, conversationID: UUID) async {
        try? await Task.sleep(for: .milliseconds(100))
    }
}

struct BackendConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    static var current: BackendConfiguration? {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https",
              let rawKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            return nil
        }
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return BackendConfiguration(url: url, publishableKey: key)
    }

    static var isConfigured: Bool { current != nil }
}

enum ProductServiceFactory {
    static func make() -> any ProductService {
        guard let configuration = BackendConfiguration.current else {
            return DemoProductService()
        }
        return SupabaseProductService(configuration: configuration)
    }
}
