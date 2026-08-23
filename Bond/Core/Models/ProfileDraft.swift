import Foundation

enum ProfileGender: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    /// Kimlerin gösterileceği artık ayrı bir soru değil, cinsiyetten türetiliyor.
    /// Kadın seçen erkekleri, erkek seçen kadınları görüyor.
    var impliedDatingPreference: DatingPreference {
        switch self {
        case .female: .men
        case .male: .women
        }
    }

    var id: Self { self }
    var title: String {
        switch self {
        case .female: L10n.Gender.female
        case .male: L10n.Gender.male
        }
    }
}

enum DatingPreference: String, Codable, CaseIterable, Identifiable {
    case women
    case men
    case everyone

    var id: Self { self }
    var title: String {
        switch self {
        case .women: L10n.Dating.women
        case .men: L10n.Dating.men
        case .everyone: L10n.Dating.everyone
        }
    }
}

struct ProfileDraft: Equatable, Codable {
    var name = ""
    var birthDate = Calendar.current.date(byAdding: .year, value: -21, to: .now) ?? .now
    var university = "YÜ"
    var department = ""
    var year = "3. sınıf"
    var bio = ""
    var interests: Set<String> = []
    var gender: ProfileGender?
    /// Ayrı bir soru olarak sorulmuyor; cinsiyetten türetiliyor. Hesaplanan olması,
    /// ikisinin birbirinden ayrı düşüp tutarsız kalmasını da imkânsız kılıyor.
    var datingPreference: DatingPreference? { gender?.impliedDatingPreference }
    var relationshipIntent: RelationshipIntent = .both
    /// Sunucudan gelir. `save_my_profile` bunu parametre olarak almıyor, yani
    /// istemci kendine rozet veremiyor — buradaki değer yalnızca gösterim için.
    var badge: ProfileBadge = .none
    var discoveryFilters = DiscoveryFilters()

    private enum CodingKeys: String, CodingKey {
        case name, birthDate, university, department, year, bio, interests, gender, relationshipIntent, badge, discoveryFilters
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
        gender = try container.decodeIfPresent(ProfileGender.self, forKey: .gender)
        relationshipIntent = try container.decodeIfPresent(RelationshipIntent.self, forKey: .relationshipIntent) ?? .both
        badge = try container.decodeIfPresent(ProfileBadge.self, forKey: .badge) ?? .none
        discoveryFilters = try container.decodeIfPresent(DiscoveryFilters.self, forKey: .discoveryFilters) ?? DiscoveryFilters()
    }

    var age: Int {
        max(18, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 18)
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

/// Hangi sınıra takılındı. Paywall'daki başlık buna göre değişiyor: "beğeni
/// hakkın bitti" ile "buluşma isteği hakkın bitti" farklı anlar.
enum QuotaKind {
    case like, meetingRequest, meetingAccept

    var title: String {
        switch self {
        case .like: L10n.Quota.likeTitle
        case .meetingRequest: L10n.Quota.meetingRequestTitle
        case .meetingAccept: L10n.Quota.meetingAcceptTitle
        }
    }

    var detail: String {
        switch self {
        case .like: L10n.Quota.likeDetail
        case .meetingRequest: L10n.Quota.meetingRequestDetail
        case .meetingAccept: L10n.Quota.meetingAcceptDetail
        }
    }
}
