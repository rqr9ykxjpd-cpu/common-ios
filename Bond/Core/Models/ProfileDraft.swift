import Foundation

struct ProfileDraft: Equatable, Codable {
    var name = ""
    var birthDate = Calendar.current.date(byAdding: .year, value: -21, to: .now) ?? .now
    var university = "YÜ"
    var department = ""
    var year = "3. sınıf"
    var bio = ""
    var interests: Set<String> = []
    /// Sunucudan gelir. `save_my_profile` bunu parametre olarak almıyor, yani
    /// istemci kendine rozet veremiyor — buradaki değer yalnızca gösterim için.
    var badge: ProfileBadge = .none
    /// Sunucudaki `profiles.ghost_mode`. UserDefaults'a yazılmaz; hayalet
    /// tercihi `AppState.ghostMode` üzerinden gider.
    var ghostMode: Bool? = nil

    private enum CodingKeys: String, CodingKey {
        case name, birthDate, university, department, year, bio, interests, badge
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        birthDate = try container.decodeIfPresent(Date.self, forKey: .birthDate) ?? (Calendar.current.date(byAdding: .year, value: -21, to: .now) ?? .now)
        university = try container.decodeIfPresent(String.self, forKey: .university) ?? "YÜ"
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        year = try container.decodeIfPresent(String.self, forKey: .year) ?? "3. sınıf"
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        interests = try container.decodeIfPresent(Set<String>.self, forKey: .interests) ?? []
        badge = try container.decodeIfPresent(ProfileBadge.self, forKey: .badge) ?? .none
    }

    var age: Int {
        max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
    }

    /// Hakkında isteğe bağlı: zorunlu alanlar doluysa %90, bio da varsa %100.
    func completionPercent(hasAvatar: Bool) -> Int {
        let required = [
            hasAvatar,
            !name.trimmed.isEmpty,
            !department.trimmed.isEmpty,
            interests.count >= InterestCatalog.minimumSelection
        ]
        let filled = required.filter { $0 }.count
        let base = Int((Double(filled) / Double(required.count) * 90).rounded())
        let about = bio.trimmed.isEmpty ? 0 : 10
        return min(100, base + about)
    }
}

/// Kişi profilinde gösterilenler, arayüzün beklediği biçimde.
struct PersonProfileData {
    var interests: [String]
    var galleryURLs: [URL]
    var avatarURL: URL?
    /// bkz. `PersonDetails.badge`.
    var badge: ProfileBadge?
    var posts: [SocialPost]
}

/// Hangi sınıra takılındı. Paywall'daki başlık buna göre değişiyor:
/// gönderi tavanı ile buluşma isteği tavanı farklı anlar.
enum QuotaKind {
    case connectionRequest, meetingRequest, meetingAccept, posts

    var title: String {
        switch self {
        case .connectionRequest: L10n.Quota.connectionRequestTitle
        case .meetingRequest: L10n.Quota.meetingRequestTitle
        case .meetingAccept: L10n.Quota.meetingAcceptTitle
        case .posts: L10n.Quota.postTitle
        }
    }

    var detail: String {
        switch self {
        case .connectionRequest: L10n.Quota.connectionRequestDetail
        case .meetingRequest: L10n.Quota.meetingRequestDetail
        case .meetingAccept: L10n.Quota.meetingAcceptDetail
        case .posts: L10n.Quota.postDetail
        }
    }
}
