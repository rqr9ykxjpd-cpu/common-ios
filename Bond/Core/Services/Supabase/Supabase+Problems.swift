import Foundation
import Supabase

/// "Sorun bildir". Tabloya doğrudan erişim yok; sunucudaki fonksiyonlar
/// (`20260927020000_problem_reports.sql`) sınırı ve yetkiyi uyguluyor.
extension SupabaseProductService {
    func reportProblem(_ message: String, context: [String: String]) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        do {
            try await client
                .rpc("report_problem", params: ProblemReportParams(message: message, context: context))
                .execute()
        } catch {
            throw ProblemReportError.from(error) ?? error
        }
    }

    func fetchProblemReports() async throws -> [ProblemReport] {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        let rows: [ProblemReportRow] = try await client.rpc("list_problem_reports").execute().value
        let fotolar = await signedURLs(bucket: "profile-photos", paths: rows.compactMap(\.reporterAvatarPath))
        return rows.map { row in
            ProblemReport(
                id: row.id,
                message: row.message,
                createdAt: row.createdAt,
                handledAt: row.handledAt,
                reporterName: row.reporterName,
                reporterUsername: row.reporterUsername,
                contextLine: ProblemReportContext.line(from: row.context ?? [:]),
                status: .init(server: row.status ?? (row.handledAt == nil ? "open" : "resolved")),
                replyCount: row.replyCount ?? 0,
                staffUnread: row.staffUnread ?? false,
                screen: row.context?["screen"],
                reporterAvatarURL: row.reporterAvatarPath.flatMap { fotolar[$0] }
            )
        }
    }

    func closeProblemReport(_ id: UUID) async throws {
        guard currentUserID != nil else { throw BackendServiceError.missingSession }
        try await client.rpc("close_problem_report", params: CloseProblemReportParams(reportID: id)).execute()
    }
}

struct ProblemReportParams: Encodable {
    let message: String
    let context: [String: String]
}

struct CloseProblemReportParams: Encodable {
    let reportID: UUID
    enum CodingKeys: String, CodingKey { case reportID = "report_id" }
}

struct ProblemReportRow: Decodable {
    let id: UUID
    let message: String
    let context: [String: String]?
    let createdAt: Date
    let handledAt: Date?
    let reporterName: String?
    let reporterUsername: String?
    let status: String?
    let replyCount: Int?
    let staffUnread: Bool?
    let reporterAvatarPath: String?

    enum CodingKeys: String, CodingKey {
        case id, message, context, status
        case createdAt = "created_at"
        case handledAt = "handled_at"
        case reporterName = "reporter_name"
        case reporterUsername = "reporter_username"
        case replyCount = "reply_count"
        case staffUnread = "staff_unread"
        case reporterAvatarPath = "reporter_avatar_path"
    }
}
