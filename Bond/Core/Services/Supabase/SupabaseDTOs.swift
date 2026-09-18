import Foundation

struct VisiblePlaceParams: Encodable {
    let targetPlace: UUID?
    enum CodingKeys: String, CodingKey { case targetPlace = "target_place" }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let targetPlace { try container.encode(targetPlace, forKey: .targetPlace) }
        else { try container.encodeNil(forKey: .targetPlace) }
    }
}

struct PlacePeopleParams: Encodable {
    let targetPlace: UUID
    enum CodingKeys: String, CodingKey { case targetPlace = "target_place" }
}

struct PlacePersonRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    /// Sunucuda `badge` kolonu yoksa (migration henüz çalıştırılmadıysa) nil gelir.
    /// Zorunlu tutmak, tek bir eksik kolon yüzünden girişi tamamen kırıyordu.
    let badge: ProfileBadge?
    let interests: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case badge
    }
}

struct CampusPeoplePageParams: Encodable {
    let pageLimit: Int
    let pageOffset: Int
    enum CodingKeys: String, CodingKey {
        case pageLimit = "page_limit"
        case pageOffset = "page_offset"
    }
}

struct CampusPersonRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    let badge: ProfileBadge?
    let interests: [String]
    let visiblePlaceID: UUID?
    let visiblePlaceName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests, badge
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case visiblePlaceID = "visible_place_id"
        case visiblePlaceName = "visible_place_name"
    }
}

struct ClubMemberIDRow: Decodable {
    let userID: UUID
    enum CodingKeys: String, CodingKey { case userID = "user_id" }
}

struct ClubRow: Decodable {
    let id: UUID
    let name: String
    let summary: String
    let icon: String
    let nextEvent: String
    let accentHex: String
    let place: PlaceRow?
    let members: [ClubMemberIDRow]?

    enum CodingKeys: String, CodingKey {
        case id, name, summary, icon, place
        case nextEvent = "next_event"
        case accentHex = "accent_hex"
        case members = "club_members"
    }
}

struct ClubMemberInsert: Encodable {
    let clubID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case userID = "user_id"
    }
}

struct StoryViewerIDRow: Decodable {
    let viewerID: UUID
    let viewCount: Int?
    let lastViewedAt: Date?
    enum CodingKeys: String, CodingKey {
        case viewerID = "viewer_id"
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
    }
}

struct StoryViewListRow: Decodable {
    let storyID: UUID
    let viewerID: UUID
    let viewCount: Int
    let lastViewedAt: Date
    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case viewerID = "viewer_id"
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
    }
}

struct StoryRow: Decodable {
    let id: UUID
    let authorID: UUID
    let mediaPath: String
    let caption: String
    let createdAt: Date
    let expiresAt: Date
    let author: SupabaseProfileRow?
    let place: PlaceRow?
    let storyViews: [StoryViewerIDRow]?
    let mediaKind: String?
    let durationMs: Int?
    let posterPath: String?

    enum CodingKeys: String, CodingKey {
        case id, caption, author, place
        case authorID = "author_id"
        case mediaPath = "media_path"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case storyViews = "story_views"
        case mediaKind = "media_kind"
        case durationMs = "duration_ms"
        case posterPath = "poster_path"
    }

    var kind: StoryMediaKind {
        StoryMediaKind(rawValue: mediaKind ?? "") ?? .image
    }
}

struct StoryInsert: Encodable {
    let authorID: UUID
    let mediaPath: String
    let caption: String
    let placeID: UUID?
    /// Süreyi sunucunun sütun varsayılanına bırakmıyoruz; tek kaynak
    /// `CampusStory.lifetime` olsun ki süre değiştirmek migration gerektirmesin.
    let expiresAt: Date
    let mediaKind: String
    let durationMs: Int?
    let posterPath: String?
    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case mediaPath = "media_path"
        case caption
        case placeID = "place_id"
        case expiresAt = "expires_at"
        case mediaKind = "media_kind"
        case durationMs = "duration_ms"
        case posterPath = "poster_path"
    }
}

struct StoryViewUpsert: Encodable {
    let storyID: UUID
    let viewerID: UUID
    let viewCount: Int
    let lastViewedAt: Date
    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case viewerID = "viewer_id"
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
    }
}

struct StoryViewCountRow: Decodable {
    let viewCount: Int
    enum CodingKeys: String, CodingKey { case viewCount = "view_count" }
}

struct StoryViewRow: Decodable {
    let viewerID: UUID
    let viewCount: Int
    let lastViewedAt: Date
    let viewer: SupabaseProfileRow?
    enum CodingKeys: String, CodingKey {
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
        case viewer
        case viewerID = "viewer_id"
    }
}

struct PlaceRow: Decodable {
    let id: UUID
    let name: String
    let area: String
}

struct StudyGroupRow: Decodable {
    let id: UUID
    let hostID: UUID
    let startsAt: Date
    let note: String
    let capacity: Int?
    let createdAt: Date
    let spotPhotoPath: String?
    let spotPhotoAt: Date?
    let place: PlaceRow?
    let host: SupabaseProfileRow?
    let members: [StudyGroupMemberRow]

    enum CodingKeys: String, CodingKey {
        case id, note, capacity, place, host, members
        case hostID = "host_id"
        case startsAt = "starts_at"
        case createdAt = "created_at"
        case spotPhotoPath = "spot_photo_path"
        case spotPhotoAt = "spot_photo_at"
    }
}

struct StudyGroupSpotParams: Encodable { let target: UUID; let path: String }

struct StudyGroupMemberRow: Decodable {
    let userID: UUID
    let joinedAt: Date
    let profile: SupabaseProfileRow?
    enum CodingKeys: String, CodingKey {
        case profile
        case userID = "user_id"
        case joinedAt = "joined_at"
    }
}

struct StudyGroupInsert: Encodable {
    let hostID: UUID
    let placeID: UUID
    let startsAt: Date
    let note: String
    let capacity: Int?
    enum CodingKeys: String, CodingKey {
        case note, capacity
        case hostID = "host_id"
        case placeID = "place_id"
        case startsAt = "starts_at"
    }
}

struct StudyGroupMemberInsert: Encodable {
    let groupID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case userID = "user_id"
    }
}


struct PlacePresenceRow: Decodable {
    let placeID: UUID
    let peopleCount: Int
    let avatarPaths: [String]?
    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case peopleCount = "people_count"
        case avatarPaths = "avatar_paths"
    }
}

struct MeetingRequestRow: Decodable {
    let id: UUID
    let requesterID: UUID
    let recipientID: UUID
    let status: String
    let createdAt: Date
    let place: PlaceRow?
    let requester: SupabaseProfileRow?
    let recipient: SupabaseProfileRow?

    enum CodingKeys: String, CodingKey {
        case id, status, place, requester, recipient
        case requesterID = "requester_id"
        case recipientID = "recipient_id"
        case createdAt = "created_at"
    }

    var meetingStatus: MeetingRequestStatus {
        switch status {
        case "accepted": .accepted
        case "declined": .declined
        default: .pending
        }
    }
}

struct ReportRow: Decodable {
    let id: UUID
    let reason: String
    let details: String?
    let createdAt: Date
    let handledAt: Date?
    let resolution: String?
    let reporter: SupabaseProfileRow?
    let reported: SupabaseProfileRow?
    let targetKind: ReportTarget.Kind?
    let targetID: UUID?
    let contentText: String?
    let contentMediaPath: String?
    let contentMediaBucket: String?

    enum CodingKeys: String, CodingKey {
        case id, reason, details, resolution, reporter, reported
        case createdAt = "created_at"
        case handledAt = "handled_at"
        case targetKind = "target_kind"
        case targetID = "target_id"
        case contentText = "content_text"
        case contentMediaPath = "content_media_path"
        case contentMediaBucket = "content_media_bucket"
    }
}

struct ContentReportParams: Encodable {
    let kind: String
    let contentID: UUID
    let reason: String
    let details: String?
    enum CodingKeys: String, CodingKey {
        case kind = "content_kind"
        case contentID = "content_id"
        case reason = "report_reason"
        case details = "report_details"
    }
}

struct ResolveReportParams: Encodable {
    let reportID: UUID
    let resolution: String
    enum CodingKeys: String, CodingKey {
        case reportID = "report_id"
        case resolution = "report_resolution"
    }
}

struct AccountActiveParams: Encodable {
    let account: UUID
    let active: Bool
}

struct MessageRequestRow: Decodable {
    let id: UUID
    let senderID: UUID
    let recipientID: UUID
    let body: String
    let status: String
    let createdAt: Date
    let sender: SupabaseProfileRow?
    let recipient: SupabaseProfileRow?

    enum CodingKeys: String, CodingKey {
        case id, body, status, sender, recipient
        case senderID = "sender_id"
        case recipientID = "recipient_id"
        case createdAt = "created_at"
    }

    var requestStatus: MeetingRequestStatus {
        switch status {
        case "accepted": .accepted
        case "declined": .declined
        default: .pending
        }
    }
}

struct MessageRequestInsert: Encodable {
    let senderID: UUID
    let recipientID: UUID
    let body: String
    let storyID: UUID?
    enum CodingKeys: String, CodingKey {
        case body
        case senderID = "sender_id"
        case recipientID = "recipient_id"
        case storyID = "story_id"
    }
}

struct MessageRequestAcceptParams: Encodable {
    let request: UUID
}

struct MeetingRequestInsert: Encodable {
    let requesterID: UUID
    let recipientID: UUID
    let placeID: UUID
    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case recipientID = "recipient_id"
        case placeID = "place_id"
    }
}

struct MeetingRequestAcceptParams: Encodable {
    let request: UUID
}

struct MeetingRequestStatusUpdate: Encodable {
    let status: String
}

struct NotificationActorRow: Decodable {
    let name: String
    let avatarPath: String?
    enum CodingKeys: String, CodingKey {
        case name
        case avatarPath = "avatar_path"
    }
}

struct NotificationRow: Decodable {
    let id: UUID
    let kind: String
    let title: String
    let body: String
    let actorID: UUID?
    let matchID: UUID?
    let isRead: Bool
    let createdAt: Date
    let actor: NotificationActorRow?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body, actor
        case actorID = "actor_id"
        case matchID = "match_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    var appKind: AppNotificationKind {
        switch kind {
        case "like": .like
        case "comment": .comment
        case "match": .match
        case "message": .message
        case "club": .club
        case "announcement": .announcement
        case "study_group": .studyGroup
        default: .meetingRequest
        }
    }
}

struct NotificationReadUpdate: Encodable {
    let isRead: Bool
    enum CodingKeys: String, CodingKey { case isRead = "is_read" }
}

struct DeviceTokenUpsert: Encodable {
    let userID: UUID
    let token: String
    let platform: String
    let updatedAt: Date
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token, platform
        case updatedAt = "updated_at"
    }
}

struct GhostModeParams: Encodable {
    let enabled: Bool
}

struct MyProfileRow: Decodable {
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let interests: [String]
    let ghostMode: Bool?

    enum CodingKeys: String, CodingKey {
        case name, university, department, bio, interests
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case ghostMode = "ghost_mode"
    }
}

struct ProfileMediaRow: Decodable {
    let avatarPath: String?
    enum CodingKeys: String, CodingKey { case avatarPath = "avatar_path" }
}

struct ProfileInterestRow: Decodable {
    let interest: String
}

struct ProfilePhotoRow: Decodable {
    let storagePath: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case storagePath = "storage_path"
        case position
    }
}

struct ProfilePhotoInsert: Encodable {
    let profileID: UUID
    let storagePath: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case storagePath = "storage_path"
        case position
    }
}

/// Composer "Kartlara ekle": sunucu sıradaki slotu verir ve 5 sınırını uygular.
struct AppendGalleryPhotoParams: Encodable {
    let storagePath: String
    enum CodingKeys: String, CodingKey {
        case storagePath = "p_storage_path"
    }
}

struct AvatarPathUpdate: Encodable {
    let path: String?
    enum CodingKeys: String, CodingKey { case path = "avatar_path" }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let path { try container.encode(path, forKey: .path) }
        else { try container.encodeNil(forKey: .path) }
    }
}

struct BlockParams: Encodable {
    let target: UUID
}

struct ReportInsert: Encodable {
    let reporterID: UUID
    let reportedID: UUID
    let reason: String
    let details: String?
    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case reportedID = "reported_id"
        case reason, details
    }
}

struct MatchRow: Decodable {
    let id: UUID
    let userA: UUID
    let userB: UUID
    let createdAt: Date
    let userAProfile: SupabaseProfileRow
    let userBProfile: SupabaseProfileRow

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "user_a"
        case userB = "user_b"
        case createdAt = "created_at"
        case userAProfile = "user_a_profile"
        case userBProfile = "user_b_profile"
    }

    func peer(for userID: UUID) -> SupabaseProfileRow {
        userA == userID ? userBProfile : userAProfile
    }
}

struct MessageEdit: Encodable {
    let body: String
    let editedAt: Date
    enum CodingKeys: String, CodingKey {
        case body
        case editedAt = "edited_at"
    }
}

struct StoryLikeInsert: Encodable {
    let storyID: UUID
    let likerID: UUID
    enum CodingKeys: String, CodingKey {
        case storyID = "story_id"
        case likerID = "liker_id"
    }
}

struct StoryLikeRow: Decodable {
    let storyID: UUID
    enum CodingKeys: String, CodingKey { case storyID = "story_id" }
}

struct MessageRow: Decodable {
    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let body: String
    let replyToID: UUID?
    let reaction: String?
    let createdAt: Date
    let readAt: Date?
    let editedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body, reaction
        case matchID = "match_id"
        case senderID = "sender_id"
        case replyToID = "reply_to_id"
        case editedAt = "edited_at"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    func message(currentUserID: UUID, allRows: [MessageRow], peerName: String) -> Message {
        let reply = replyToID.flatMap { replyID in
            allRows.first(where: { $0.id == replyID }).map {
                MessageReply(messageID: $0.id, authorName: $0.senderID == currentUserID ? L10n.Common.you : peerName, body: $0.body)
            }
        }
        return Message(id: id, body: body, isMine: senderID == currentUserID, sentAt: createdAt, reaction: reaction, editedAt: editedAt, replyTo: reply)
    }
}

struct MessageInsert: Encodable {
    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let body: String
    let replyToID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, body
        case matchID = "match_id"
        case senderID = "sender_id"
        case replyToID = "reply_to_id"
    }
}

struct MessageReadUpdate: Encodable {
    let readAt: Date
    enum CodingKeys: String, CodingKey { case readAt = "read_at" }
}

struct SaveCampusProfileParams: Encodable {
    let profileName: String
    let profileBirthDate: String
    let profileUniversity: String
    let profileDepartment: String
    let profileAcademicYear: String
    let profileBio: String
    let profileInterests: [String]

    enum CodingKeys: String, CodingKey {
        case profileName = "profile_name"
        case profileBirthDate = "profile_birth_date"
        case profileUniversity = "profile_university"
        case profileDepartment = "profile_department"
        case profileAcademicYear = "profile_academic_year"
        case profileBio = "profile_bio"
        case profileInterests = "profile_interests"
    }
}

struct MessageReactionParams: Encodable {
    let messageID: UUID
    let reaction: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_uuid"
        case reaction
    }
}

struct PurchasePayload: Encodable {
    let jws: String
    let productID: String
    enum CodingKeys: String, CodingKey {
        case jws
        case productID = "product_id"
    }
}

struct PostInsert: Encodable {
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?
    let kind: PostKind

    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case caption, kind
        case placeName = "place_name"
        case mediaPath = "media_path"
    }
}

struct CommentInsert: Encodable {
    let postID: UUID
    let authorID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case authorID = "author_id"
        case body
    }
}

struct SupabaseProfileRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    /// Sunucuda `badge` kolonu yoksa (migration henüz çalıştırılmadıysa) nil gelir.
    /// Zorunlu tutmak, tek bir eksik kolon yüzünden girişi tamamen kırıyordu.
    let badge: ProfileBadge?
    /// Yalnızca moderasyon sorgusunda seçiliyor; diğerlerinde nil.
    let isActive: Bool?

    func studentProfile(avatarURL: URL?) -> StudentProfile {
        let age = max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
        return StudentProfile(
            id: id, name: name, age: age, university: university, department: department,
            year: academicYear, bio: bio, interests: [], imageURL: avatarURL,
            isVerified: isVerified, badge: badge ?? .none
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio
        case birthDate = "birth_date"
        case avatarPath = "avatar_path"
        case academicYear = "academic_year"
        case isVerified = "is_verified"
        case badge
        case isActive = "is_active"
    }
}

struct CommentAuthorRow: Decodable {
    let name: String
    let avatarPath: String?
    enum CodingKeys: String, CodingKey {
        case name
        case avatarPath = "avatar_path"
    }
}

struct CommentRow: Decodable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let body: String
    /// Sunucunun tuttuğu net puan; oy satırları artık herkese açık değil.
    /// `boost` kurucunun eklediği oy; görünen puan ikisinin toplamı.
    let score: Int?
    let boost: Int?
    let createdAt: Date
    let author: CommentAuthorRow

    enum CodingKeys: String, CodingKey {
        case id, body, author, score, boost
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }

    /// Avatar adresi imzalı olarak dışarıdan veriliyor: imzalama toplu
    /// yapıldığı için satır başına ayrı istek atılmıyor.
    func backendComment(avatarURL: URL?, voteCount: Int = 0, voted: Bool = false, downvoted: Bool = false, boost: Int = 0) -> BackendComment {
        BackendComment(
            id: id,
            postID: postID,
            authorID: authorID,
            authorName: author.name,
            authorAvatarURL: avatarURL,
            body: body,
            createdAt: createdAt,
            voteCount: voteCount,
            voted: voted,
            downvoted: downvoted,
            boost: boost
        )
    }
}

struct PostRow: Decodable {
    let id: UUID
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?
    /// Ham metin: ileride eklenen bir tür bu sürümde düz paylaşım gibi çizilir,
    /// enum'a çözülemedi diye bütün akış düşmez.
    let kind: String?
    /// Sunucunun tuttuğu net oy; `boost` kurucunun eklediği oy; `pinnedAt` sabit.
    let score: Int?
    let boost: Int?
    let pinnedAt: Date?
    let pinnedSlot: Int?
    let createdAt: Date
    let author: SupabaseProfileRow
    let comments: [CommentRow]

    enum CodingKeys: String, CodingKey {
        case id, caption, author, comments, kind, score, boost
        case authorID = "author_id"
        case placeName = "place_name"
        case mediaPath = "media_path"
        case pinnedAt = "pinned_at"
        case pinnedSlot = "pinned_slot"
        case createdAt = "created_at"
    }

    /// Puan sunucudan (`score + boost`); oy satırları yalnızca kişinin kendi oyunu söyler.
    func backendPost(imageData: Data?, authorAvatarURL: URL?, liked: Bool, downvoted: Bool = false, saved: Bool, badge: ProfileBadge = .none, commentAvatarURLs: [String: URL] = [:], imageURL: URL? = nil, commentVotes: [CommentVoteRow] = [], userID: UUID? = nil) -> BackendPost {
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
            authorBadge: badge,
            authorAvatarURL: authorAvatarURL,
            caption: caption,
            placeName: placeName,
            kind: kind.flatMap(PostKind.init(rawValue:)) ?? .moment,
            imageData: imageData,
            imageURL: imageURL,
            createdAt: createdAt,
            comments: comments.sorted { $0.createdAt < $1.createdAt }
                .map { comment in
                    let oylar = commentVotes.filter { $0.commentID == comment.id }
                    let benim = userID.flatMap { id in oylar.first { $0.userID == id }?.value } ?? 0
                    return comment.backendComment(
                        avatarURL: comment.author.avatarPath.flatMap { commentAvatarURLs[$0] },
                        voteCount: (comment.score ?? 0) + (comment.boost ?? 0),
                        voted: benim == 1,
                        downvoted: benim == -1,
                        boost: comment.boost ?? 0
                    )
                },
            likeCount: (score ?? 0) + (boost ?? 0),
            liked: liked,
            downvoted: downvoted,
            saved: saved,
            boost: boost ?? 0,
            pinnedAt: pinnedAt,
            pinnedSlot: pinnedSlot
        )
    }
}

/// Kurucu/moderatörün gördüğü oy veren listesi.
struct PostVoterRow: Decodable {
    let id: UUID
    let name: String
    let avatarPath: String?
    let value: Int
    enum CodingKeys: String, CodingKey {
        case id, name, value
        case avatarPath = "avatar_path"
    }
}

struct PostVoterParams: Encodable { let target: UUID }
struct FounderUserRow: Decodable {
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
    enum CodingKeys: String, CodingKey {
        case id, name, department, badge, plan
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
    }
}
struct FounderUsersParams: Encodable { let search: String; let lim: Int }
struct FounderGrantParams: Encodable {
    let target: UUID; let newPlan: String; let days: Int?
    enum CodingKeys: String, CodingKey { case target, days; case newPlan = "new_plan" }
}
struct FounderModeratorParams: Encodable { let target: UUID; let enabled: Bool }
struct FounderActiveParams: Encodable { let target: UUID; let active: Bool }
struct FounderDayRow: Decodable {
    let day: String
    let newUsers: Int
    let activeUsers: Int
    let posts: Int
    let matches: Int?
    enum CodingKeys: String, CodingKey { case day, posts, matches; case newUsers = "new_users"; case activeUsers = "active_users" }
}
struct FounderDaysParams: Encodable { let days: Int }
struct FounderAnnouncementRow: Decodable {
    let title: String
    let body: String
    let sentAt: Date
    let recipients: Int
    enum CodingKeys: String, CodingKey { case title, body, recipients; case sentAt = "sent_at" }
}
struct FounderAnnouncementsParams: Encodable { let lim: Int }
struct BroadcastParams: Encodable {
    let title: String
    let body: String
    let testOnly: Bool
    enum CodingKeys: String, CodingKey { case title, body; case testOnly = "test_only" }
}
struct BoostParams: Encodable { let target: UUID; let extra: Int }
struct PinParams: Encodable { let target: UUID; let slot: Int? }

struct RightSwipeParams: Encodable {
    let subject: UUID
}

struct ProfileSwiperRow: Decodable {
    let id: UUID
    let name: String
    let avatarPath: String?
    let direction: String
    let swipedAt: Date
    let isMatched: Bool
    enum CodingKeys: String, CodingKey {
        case id, name, direction
        case avatarPath = "avatar_path"
        case swipedAt = "swiped_at"
        case isMatched = "is_matched"
    }
}

struct RightSwipeRow: Decodable {
    let matched: Bool
    let matchID: UUID?

    enum CodingKeys: String, CodingKey {
        case matched
        case matchID = "match_id"
    }
}

struct RightSwipeOutcome: Sendable {
    let matched: Bool
    let matchID: UUID?
}

struct UnmatchParams: Encodable {
    let matchUUID: UUID
    enum CodingKeys: String, CodingKey { case matchUUID = "match_uuid" }
}

struct ProfileVisitParams: Encodable {
    let target: UUID
}

struct ProfileVisitRow: Decodable {
    let visitorID: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let isVerified: Bool
    /// Sunucuda `badge` kolonu yoksa (migration henüz çalıştırılmadıysa) nil gelir.
    /// Zorunlu tutmak, tek bir eksik kolon yüzünden girişi tamamen kırıyordu.
    let badge: ProfileBadge?
    let lastVisitedAt: Date

    enum CodingKeys: String, CodingKey {
        case name, university, department, bio
        case visitorID = "visitor_id"
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case badge
        case lastVisitedAt = "last_visited_at"
    }
}

struct SavedPostRow: Decodable {
    let postID: UUID
    enum CodingKeys: String, CodingKey { case postID = "post_id" }
}

struct SavedPostInsert: Encodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}

struct PostLikeRow: Decodable {
    let postID: UUID
    let userID: UUID
    /// +1 yukarı, -1 aşağı.
    let value: Int
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case value
    }
}

struct CommentVoteRow: Decodable {
    let commentID: UUID
    let userID: UUID
    let value: Int
    enum CodingKeys: String, CodingKey {
        case commentID = "comment_id"
        case userID = "user_id"
        case value
    }
}

struct CommentVoteInsert: Encodable {
    let commentID: UUID
    let userID: UUID
    let value: Int
    enum CodingKeys: String, CodingKey {
        case commentID = "comment_id"
        case userID = "user_id"
        case value
    }
}

struct PostLikeInsert: Encodable {
    let postID: UUID
    let userID: UUID
    let value: Int
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
        case value
    }
}

struct ProfileBadgeRow: Decodable {
    let id: UUID
    /// Kolon yoksa nil gelir; bkz. `badges(for:)`.
    let badge: ProfileBadge?
}

struct MediaPathRow: Decodable {
    let mediaPath: String?
    enum CodingKeys: String, CodingKey { case mediaPath = "media_path" }
}

struct ExpiredStoryRow: Decodable {
    let id: UUID
    let mediaPath: String?
    let posterPath: String?
    enum CodingKeys: String, CodingKey {
        case id
        case mediaPath = "media_path"
        case posterPath = "poster_path"
    }
}

