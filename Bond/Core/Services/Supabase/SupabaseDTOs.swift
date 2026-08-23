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
    let relationshipIntent: RelationshipIntent
    let interests: [String]
    let activeLabel: String

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case badge
        case relationshipIntent = "relationship_intent"
        case activeLabel = "active_label"
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
    enum CodingKeys: String, CodingKey { case viewerID = "viewer_id" }
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

    enum CodingKeys: String, CodingKey {
        case id, caption, author, place
        case authorID = "author_id"
        case mediaPath = "media_path"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case storyViews = "story_views"
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
    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case mediaPath = "media_path"
        case caption
        case placeID = "place_id"
        case expiresAt = "expires_at"
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
    let viewCount: Int
    let lastViewedAt: Date
    let viewer: SupabaseProfileRow?
    enum CodingKeys: String, CodingKey {
        case viewCount = "view_count"
        case lastViewedAt = "last_viewed_at"
        case viewer
    }
}

struct PlaceRow: Decodable {
    let id: UUID
    let name: String
    let area: String
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

    enum CodingKeys: String, CodingKey {
        case id, reason, details, resolution, reporter, reported
        case createdAt = "created_at"
        case handledAt = "handled_at"
    }
}

struct ReportResolutionUpdate: Encodable {
    let handledAt: Date
    let handledBy: UUID
    let resolution: String
    enum CodingKeys: String, CodingKey {
        case resolution
        case handledAt = "handled_at"
        case handledBy = "handled_by"
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
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case token, platform
    }
}

struct MyProfileRow: Decodable {
    let name: String
    let birthDate: Date
    let gender: String
    let datingPreference: String
    let relationshipIntent: String
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let interests: [String]
    let promptKeys: [String]
    let promptAnswers: [String]
    let minAge: Int
    let maxAge: Int
    let academicYears: [String]
    let departments: [String]
    let requireCommonInterest: Bool
    let campusOnly: Bool

    enum CodingKeys: String, CodingKey {
        case name, gender, university, department, bio, interests, departments
        case birthDate = "birth_date"
        case datingPreference = "dating_preference"
        case relationshipIntent = "relationship_intent"
        case academicYear = "academic_year"
        case promptKeys = "prompt_keys"
        case promptAnswers = "prompt_answers"
        case minAge = "min_age"
        case maxAge = "max_age"
        case academicYears = "academic_years"
        case requireCommonInterest = "require_common_interest"
        case campusOnly = "campus_only"
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

struct SaveProfileParams: Encodable {
    let profileName: String
    let profileBirthDate: String
    let profileGender: String
    let profileDatingPreference: String
    let profileRelationshipIntent: String
    let profileUniversity: String
    let profileDepartment: String
    let profileAcademicYear: String
    let profileBio: String
    let profileInterests: [String]

    enum CodingKeys: String, CodingKey {
        case profileName = "profile_name"
        case profileBirthDate = "profile_birth_date"
        case profileGender = "profile_gender"
        case profileDatingPreference = "profile_dating_preference"
        case profileRelationshipIntent = "profile_relationship_intent"
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

struct DiscoveryPreferencesUpsert: Encodable {
    let userID: UUID
    let minAge: Int
    let maxAge: Int
    let academicYears: [String]
    let departments: [String]
    let requireCommonInterest: Bool
    let campusOnly: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case minAge = "min_age"
        case maxAge = "max_age"
        case academicYears = "academic_years"
        case departments
        case requireCommonInterest = "require_common_interest"
        case campusOnly = "campus_only"
    }
}

struct DiscoveryPageParams: Encodable {
    let pageLimit: Int
    let pageOffset: Int
    enum CodingKeys: String, CodingKey {
        case pageLimit = "page_limit"
        case pageOffset = "page_offset"
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

struct ReactionParams: Encodable {
    let subject: UUID
    let reaction: String
}

struct ReactionResultRow: Decodable {
    let matched: Bool
    let matchID: UUID?
    enum CodingKeys: String, CodingKey {
        case matched
        case matchID = "match_id"
    }
}

struct DiscoveryCandidateRow: Decodable {
    let id: UUID
    let name: String
    let birthDate: Date
    let university: String
    let department: String
    let academicYear: String
    let bio: String
    let avatarPath: String?
    let galleryPaths: [String]
    let isVerified: Bool
    /// Sunucuda `badge` kolonu yoksa (migration henüz çalıştırılmadıysa) nil gelir.
    /// Zorunlu tutmak, tek bir eksik kolon yüzünden girişi tamamen kırıyordu.
    let badge: ProfileBadge?
    let relationshipIntent: RelationshipIntent
    let interests: [String]
    let promptKeys: [String]
    let promptAnswers: [String]
    let compatibility: Int
    let compatibilityReasons: [String]
    let activeLabel: String

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, interests, compatibility
        case birthDate = "birth_date"
        case avatarPath = "avatar_path"
        case galleryPaths = "gallery_paths"
        case academicYear = "academic_year"
        case isVerified = "is_verified"
        case badge
        case relationshipIntent = "relationship_intent"
        case promptKeys = "prompt_keys"
        case promptAnswers = "prompt_answers"
        case compatibilityReasons = "compatibility_reasons"
        case activeLabel = "active_label"
    }

    func studentProfile(avatarURL: URL?, galleryURLs: [URL]) -> StudentProfile {
        let age = max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
        return StudentProfile(
            id: id, name: name, age: age, university: university, department: department,
            year: academicYear, bio: bio, interests: interests, imageURL: avatarURL,
            galleryImageURLs: galleryURLs,
            compatibility: compatibility, isVerified: isVerified, badge: badge ?? .none,
            compatibilityReasons: compatibilityReasons.map(CompatibilityCopy.localize),
            relationshipIntent: relationshipIntent, activeLabel: activeLabel
        )
    }
}

struct PromptInsert: Encodable {
    let profileID: UUID
    let promptKey: String
    let answer: String
    let position: Int
    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case promptKey = "prompt_key"
        case answer, position
    }
}

struct InterestInsert: Encodable {
    let profileID: UUID
    let interest: String

    enum CodingKeys: String, CodingKey {
        case profileID = "profile_id"
        case interest
    }
}

struct PostInsert: Encodable {
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?

    enum CodingKeys: String, CodingKey {
        case authorID = "author_id"
        case caption
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
            compatibility: 0, isVerified: isVerified, badge: badge ?? .none, activeLabel: L10n.Profile.matchLabel
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
    let createdAt: Date
    let author: CommentAuthorRow

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }

    /// Avatar adresi imzalı olarak dışarıdan veriliyor: imzalama toplu
    /// yapıldığı için satır başına ayrı istek atılmıyor.
    func backendComment(avatarURL: URL?) -> BackendComment {
        BackendComment(
            id: id,
            postID: postID,
            authorID: authorID,
            authorName: author.name,
            authorAvatarURL: avatarURL,
            body: body,
            createdAt: createdAt
        )
    }
}

struct PostRow: Decodable {
    let id: UUID
    let authorID: UUID
    let caption: String
    let placeName: String?
    let mediaPath: String?
    let createdAt: Date
    let author: SupabaseProfileRow
    let comments: [CommentRow]

    enum CodingKeys: String, CodingKey {
        case id, caption, author, comments
        case authorID = "author_id"
        case placeName = "place_name"
        case mediaPath = "media_path"
        case createdAt = "created_at"
    }

    func backendPost(imageData: Data?, authorAvatarURL: URL?, likeCount: Int, liked: Bool, saved: Bool, badge: ProfileBadge = .none, commentAvatarURLs: [String: URL] = [:]) -> BackendPost {
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
            imageData: imageData,
            createdAt: createdAt,
            comments: comments.sorted { $0.createdAt < $1.createdAt }
                .map { $0.backendComment(avatarURL: $0.author.avatarPath.flatMap { commentAvatarURLs[$0] }) },
            likeCount: likeCount,
            liked: liked,
            saved: saved
        )
    }
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
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
    }
}

struct PostLikeInsert: Encodable {
    let postID: UUID
    let userID: UUID
    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case userID = "user_id"
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
    enum CodingKeys: String, CodingKey { case id, mediaPath = "media_path" }
}

struct AdmirerRow: Decodable {
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
    let likedAt: Date
    let isMatched: Bool

    func admirer(avatarURL: URL?) -> Admirer {
        let age = max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
        return Admirer(
            profile: StudentProfile(
                id: id, name: name, age: age, university: university, department: department,
                year: academicYear, bio: bio, interests: [], imageURL: avatarURL,
                compatibility: 0, isVerified: isVerified, badge: badge ?? .none,
                activeLabel: L10n.Profile.matchLabel
            ),
            likedAt: likedAt,
            isMatched: isMatched
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, university, department, bio, badge
        case birthDate = "birth_date"
        case academicYear = "academic_year"
        case avatarPath = "avatar_path"
        case isVerified = "is_verified"
        case likedAt = "liked_at"
        case isMatched = "is_matched"
    }
}
