import Foundation
import Supabase

/// Destek talepleri. Tablolara doğrudan erişim yok; sunucudaki fonksiyonlar
/// (`20261001010000_support_threads.sql`) yetkiyi ve sınırı uyguluyor.
extension SupabaseProductService: SupportDesk {
    func fetchMySupportThreads() async throws -> [SupportThread] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [SupportThreadRow] = try await client.rpc("get_my_support_threads").execute().value
        return rows.map {
            SupportThread(id: $0.id, message: $0.message, screen: $0.screen,
                          status: .init(server: $0.status), createdAt: $0.createdAt,
                          lastMessageAt: $0.lastMessageAt ?? $0.createdAt, hasUnread: $0.hasUnread ?? false)
        }
    }

    func fetchSupportMessages(_ reportID: UUID) async throws -> [SupportMessage] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [SupportMessageRow] = try await client
            .rpc("get_support_messages", params: SupportReportParams(reportID: reportID))
            .execute().value
        return rows.map { SupportMessage(id: $0.id, fromStaff: $0.fromStaff, body: $0.body, createdAt: $0.createdAt) }
    }

    func sendSupportMessage(_ reportID: UUID, body: String, resolve: Bool) async throws -> SupportThread.Status {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        do {
            let durum: String = try await client
                .rpc("send_support_message", params: SupportSendParams(reportID: reportID, body: body, resolve: resolve))
                .execute().value
            return .init(server: durum)
        } catch {
            throw ProblemReportError.from(error) ?? error
        }
    }

    func setEduExempt(_ userID: UUID, exempt: Bool) async throws -> Bool {
        try await client
            .rpc("founder_set_edu_exempt", params: EduExemptParams(target: userID, exempt: exempt))
            .execute().value
    }

    func fetchEduGate() async throws -> Bool {
        try await client.rpc("get_edu_gate").execute().value
    }

    func setEduGate(_ enabled: Bool) async throws -> Bool {
        try await client.rpc("founder_set_edu_gate", params: EduGateParams(enabled: enabled)).execute().value
    }
}

struct EduGateParams: Encodable { let enabled: Bool }

struct SupportReportParams: Encodable {
    let reportID: UUID
    enum CodingKeys: String, CodingKey { case reportID = "report_id" }
}

struct SupportSendParams: Encodable {
    let reportID: UUID
    let body: String
    let resolve: Bool
    enum CodingKeys: String, CodingKey { case body, resolve; case reportID = "report_id" }
}

struct EduExemptParams: Encodable { let target: UUID; let exempt: Bool }

struct SupportThreadRow: Decodable {
    let id: UUID
    let message: String
    let screen: String?
    let status: String?
    let createdAt: Date
    let lastMessageAt: Date?
    let hasUnread: Bool?
    enum CodingKeys: String, CodingKey {
        case id, message, screen, status
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case hasUnread = "has_unread"
    }
}

struct SupportMessageRow: Decodable {
    let id: UUID
    let fromStaff: Bool
    let body: String
    let createdAt: Date
    enum CodingKeys: String, CodingKey {
        case id, body
        case fromStaff = "from_staff"
        case createdAt = "created_at"
    }
}

/// Kurucu kullanıcı listesi satırı; doğrulama durumuyla birlikte.
struct FounderUserListRow: Decodable {
    let id: UUID
    let name: String
    let department: String
    let academicYear: String
    let avatarPath: String?
    let badge: String
    let isVerified: Bool
    let isActive: Bool
    let plan: String
    let createdAt: Date
    let lastActiveAt: Date
    let eduExempt: Bool?
    let eduVerified: Bool?
    let hasPush: Bool?
    enum CodingKeys: String, CodingKey {
        case id, name, department, badge, plan
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case eduExempt = "edu_exempt"
        case eduVerified = "edu_verified"
        case hasPush = "has_push"
    }
}
