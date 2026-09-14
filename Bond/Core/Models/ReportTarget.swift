import Foundation

/// The exact piece of content selected by the reporter. Its owner and evidence
/// are resolved on the server; the client cannot nominate another person's content.
struct ReportTarget: Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case post, story, comment, message

        var title: String {
            switch self {
            case .post: L10n.ContentReport.post
            case .story: L10n.ContentReport.story
            case .comment: L10n.ContentReport.comment
            case .message: L10n.ContentReport.message
            }
        }
    }

    let kind: Kind
    let id: UUID
}
