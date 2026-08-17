import Foundation
import Supabase

struct BackendComment: Sendable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let authorName: String
    let body: String
    let createdAt: Date
}

struct BackendPost: Sendable {
    let id: UUID
    let authorID: UUID
    let authorName: String
    let authorBirthDate: Date
    let authorUniversity: String
    let authorDepartment: String
    let authorYear: String
    let authorBio: String
    let authorVerified: Bool
    let caption: String
    let placeName: String?
    let createdAt: Date
    let comments: [BackendComment]
}

enum BackendServiceError: LocalizedError {
    case missingConfiguration
    case missingSession
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Supabase yapılandırması eksik. Project URL ve publishable key eklenmeli."
        case .missingSession:
            "Oturum bulunamadı. Lütfen tekrar giriş yap."
        case .incompleteProfile:
            "Cinsiyet ve tanışma tercihi zorunludur."
        }
    }
}

final class SupabaseProductService: ProductService, @unchecked Sendable {
    let isDemo = false
    private let client: SupabaseClient

    var currentUserID: UUID? { client.auth.currentUser?.id }

    init(configuration: BackendConfiguration) {
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }

    func requestOTP(email: String) async throws {
        try await client.auth.signInWithOTP(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    func verifyOTP(email: String, code: String) async throws {
        try await client.auth.verifyOTP(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            token: code,
            type: .email
        )
    }

    func restoreSession() async throws -> UUID? {
        guard client.auth.currentSession != nil else { return nil }
        return try await client.auth.session.user.id
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func saveProfile(_ draft: ProfileDraft) async throws {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        guard let gender = draft.gender,
              let datingPreference = draft.datingPreference else {
            throw BackendServiceError.incompleteProfile
        }

        let profile = ProfileUpsert(
            id: userID,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: draft.birthDate,
            gender: gender.rawValue,
            datingPreference: datingPreference.rawValue,
            university: draft.university,
            department: draft.department.trimmingCharacters(in: .whitespacesAndNewlines),
            academicYear: draft.year,
            bio: draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await client.from("profiles").upsert(profile).execute()

        try await client
            .from("profile_interests")
            .delete(returning: .minimal)
            .eq("profile_id", value: userID)
            .execute()

        let interests = draft.interests.sorted().map {
            InterestInsert(profileID: userID, interest: $0)
        }
        if !interests.isEmpty {
            try await client.from("profile_interests").insert(interests).execute()
        }
    }

    func fetchFeed() async throws -> [BackendPost] {
        let rows: [PostRow] = try await client
            .from("posts")
            .select("id,author_id,caption,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name))")
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
        return rows.map(\.backendPost)
    }

    func createPost(caption: String, placeName: String?) async throws -> BackendPost {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let payload = PostInsert(
            authorID: userID,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            placeName: placeName
        )
        let row: PostRow = try await client
            .from("posts")
            .insert(payload)
            .select("id,author_id,caption,place_name,created_at,author:profiles!posts_author_id_fkey(id,name,birth_date,university,department,academic_year,bio,is_verified),comments(id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name))")
            .single()
            .execute()
            .value
        return row.backendPost
    }

    func addComment(_ body: String, to postID: UUID) async throws -> BackendComment {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        let payload = CommentInsert(postID: postID, authorID: userID, body: body)
        let row: CommentRow = try await client
            .from("comments")
            .insert(payload)
            .select("id,post_id,author_id,body,created_at,author:profiles!comments_author_id_fkey(name)")
            .single()
            .execute()
            .value
        return row.backendComment
    }

    func deletePost(_ postID: UUID) async throws {
        try await client.from("posts").delete(returning: .minimal).eq("id", value: postID).execute()
    }

    func deleteComment(_ commentID: UUID) async throws {
        try await client.from("comments").delete(returning: .minimal).eq("id", value: commentID).execute()
    }

    func recordReaction(profileID: UUID, liked: Bool) async {}
    func send(_ message: Message, conversationID: UUID) async {}
}

private struct ProfileUpsert: Encodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let gender: String
    let datingPreference: String
    let university: String
    let department: String
    let academicYear: String
    let bio: String

    enum CodingKeys: String, CodingKey {
        case id, name, gender, university, department, bio
        case birthDate = "birth_date"
        case datingPreference = "dating_preference"
        case academicYear = "academic_year"
    }
}

private struct InterestInsert: Encodable {
    let profileID: UUID
    let interest: String

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case interest
    }
}

private struct PostInsert: Encodable {
    let authorID: UUID
    let caption: String
    let placeName: String?

    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case caption
        case placeName = "place_name"
    }
}

private struct CommentInsert: Encodable {
    let postID: UUID
    let authorID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case authorID = "author_id"
        case body
    }
}

private struct SupabaseProfileRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case isVerified = "is_verified"
    }
}

private struct CommentAuthorRow: Decodable {
    let name: String
}

private struct CommentRow: Decodable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let body: String
    let createdAt: Date
    let author: CommentAuthorRow

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }

    var backendComment: BackendComment {
        BackendComment(
            id: id,
            postID: postID,
            authorID: authorID,
            authorName: author.name,
            body: body,
            createdAt: createdAt
        )
    }
}

private struct PostRow: Decodable {
    let id: UUID
    let authorID: UUID
    let caption: String
    let placeName: String?
    let createdAt: Date
    let author: SupabaseProfileRow
    let comments: [CommentRow]

    enum CodingKeys: String, CodingKey {
        case id, caption, author, comments
        case authorID = "author_id"
        case placeName = "place_name"
        case createdAt = "created_at"
    }

    var backendPost: BackendPost {
        BackendPost(
            id: id,
            authorID: authorID,
            authorName: author.name,
            authorBirthDate: author.birthDate,
            authorUniversity: author.university,
            authorDepartment: author.department,
            authorYear: author.academicYear,
            authorBio: author.bio,
            authorVerified: author.isVerified,
            caption: caption,
            placeName: placeName,
            createdAt: createdAt,
            comments: comments.sorted { $0.createdAt < $1.createdAt }.map(\.backendComment)
        )
    }
}
