import Foundation

struct MessageReply: Hashable, Codable {
    let messageID: UUID
    let authorName: String
    let body: String
}

struct Message: Identifiable, Hashable, Codable {
    let id: UUID
    let body: String
    let isMine: Bool
    let sentAt: Date
    var reaction: String?
    let replyTo: MessageReply?

    init(id: UUID = UUID(), body: String, isMine: Bool, sentAt: Date, reaction: String? = nil, replyTo: MessageReply? = nil) {
        self.id = id
        self.body = body
        self.isMine = isMine
        self.sentAt = sentAt
        self.reaction = reaction
        self.replyTo = replyTo
    }
}

struct Conversation: Identifiable, Hashable {
    let id: UUID
    let profile: StudentProfile
    var messages: [Message]
    var updatedAt: Date
    var unreadCount: Int

    var lastMessage: String { messages.last?.body ?? "Yeni bir eşleşme" }

    static let samples: [Conversation] = [
        Conversation(id: UUID(), profile: StudentProfile.samples[1], messages: [
            Message(body: "Perşembe akşamı o sergiye gidelim mi?", isMine: false, sentAt: .now.addingTimeInterval(-420))
        ], updatedAt: .now.addingTimeInterval(-420), unreadCount: 1),
        Conversation(id: UUID(), profile: StudentProfile.samples[0], messages: [
            Message(body: "Playlist'i dinledim, üçüncü şarkı çok iyi.", isMine: false, sentAt: .now.addingTimeInterval(-3600), reaction: "❤️"),
            Message(body: "Benim de favorim oydu.", isMine: true, sentAt: .now.addingTimeInterval(-3000))
        ], updatedAt: .now.addingTimeInterval(-3000), unreadCount: 0)
    ]
}

enum MeetingRequestStatus: String, Hashable {
    case pending, accepted, declined

    var title: String {
        switch self {
        case .pending: "Bekliyor"
        case .accepted: "Kabul edildi"
        case .declined: "Reddedildi"
        }
    }
}

enum MeetingRequestDirection: Hashable {
    case incoming, outgoing
}

struct MeetingRequest: Identifiable, Hashable {
    let id: UUID
    let profile: StudentProfile
    let place: CampusPlace
    let direction: MeetingRequestDirection
    var status: MeetingRequestStatus
    let createdAt: Date

    init(id: UUID = UUID(), profile: StudentProfile, place: CampusPlace, direction: MeetingRequestDirection, status: MeetingRequestStatus = .pending, createdAt: Date = .now) {
        self.id = id
        self.profile = profile
        self.place = place
        self.direction = direction
        self.status = status
        self.createdAt = createdAt
    }
}

enum AppNotificationKind: Hashable {
    case like, comment, match, message, club, meetingRequest

    var systemName: String {
        switch self {
        case .like: "heart.fill"
        case .comment: "bubble.left.fill"
        case .match: "person.2.fill"
        case .message: "message.fill"
        case .club: "person.3.fill"
        case .meetingRequest: "cup.and.saucer.fill"
        }
    }
}

struct AppNotification: Identifiable, Hashable {
    let id: UUID
    let kind: AppNotificationKind
    let title: String
    let body: String
    let actor: StudentProfile?
    let meetingRequestID: UUID?
    let createdAt: Date
    var isRead: Bool

    init(id: UUID = UUID(), kind: AppNotificationKind, title: String, body: String, actor: StudentProfile? = nil, meetingRequestID: UUID? = nil, createdAt: Date = .now, isRead: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.actor = actor
        self.meetingRequestID = meetingRequestID
        self.createdAt = createdAt
        self.isRead = isRead
    }

    static let samples: [AppNotification] = [
        AppNotification(kind: .message, title: "Ece sana mesaj gönderdi", body: "Perşembe akşamı o sergiye gidelim mi?", actor: StudentProfile.samples[1], createdAt: .now.addingTimeInterval(-420)),
        AppNotification(kind: .like, title: "Defne gönderini beğendi", body: "Kampüs paylaşımın dikkatini çekti.", actor: StudentProfile.samples[0], createdAt: .now.addingTimeInterval(-1_800)),
        AppNotification(kind: .comment, title: "Mina yorum yaptı", body: "Bu etkinliğe ben de geliyorum.", actor: StudentProfile.samples[2], createdAt: .now.addingTimeInterval(-5_400), isRead: true),
        AppNotification(kind: .club, title: "Fotoğraf Topluluğu", body: "Cuma günkü kampüs yürüyüşü için yeni duyuru var.", createdAt: .now.addingTimeInterval(-14_400), isRead: true)
    ]
}

enum UniversityDomain {
    static let accepted = ["yalova.edu.tr"]

    static func isValid(_ email: String) -> Bool {
        guard let domain = email.lowercased().split(separator: "@").last else { return false }
        return accepted.contains(String(domain))
    }
}
