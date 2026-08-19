/// Profilde görünen işaret.
///
/// Daha önce mavi tik `is_verified` alanından geliyordu — ama o alan aynı zamanda
/// keşifte görünme kapısıydı ve herkeste açık olmak zorunda. Yani tik herkeste
/// çıkıyordu ve hiçbir şey ifade etmiyordu. Rozet artık ayrı bir alan ve yalnızca
/// sunucudan elle atanıyor; istemci kendine veremiyor.
enum ProfileBadge: String, Codable, Hashable {
    case none
    case verified
    case moderator
    case founder

    /// Tanımadığımız bir değer gelirse çözümleme patlamasın: sunucuya ileride yeni
    /// bir rozet eklenirse eski uygulamalar sadece rozeti göstermez, kırılmaz.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProfileBadge(rawValue: raw) ?? .none
    }

    var systemImage: String? {
        switch self {
        case .none: nil
        case .verified: "checkmark.seal.fill"
        case .moderator: "shield.lefthalf.filled"
        case .founder: "star.circle.fill"
        }
    }

    /// Profil ekranında rozetin yanında yazan açıklama.
    var title: String? {
        switch self {
        case .none: nil
        case .verified: "Doğrulanmış hesap"
        case .moderator: "Moderatör"
        case .founder: "Common kurucusu"
        }
    }
}

import Foundation

enum RelationshipIntent: String, Codable, CaseIterable, Identifiable {
    case friendship
    case dating
    case both

    var id: Self { self }
    var title: String {
        switch self {
        case .friendship: "Arkadaşlık"
        case .dating: "Flört"
        case .both: "İkisine de açığım"
        }
    }
}

struct DiscoveryFilters: Equatable, Codable {
    var minimumAge = 18
    var maximumAge = 30
    var academicYears: Set<String> = []
    var departments: Set<String> = []
    var requiresCommonInterest = false
    var campusOnly = true

    /// Varsayılandan sapan filtre sayısı. Keşif boş geldiğinde sebebin filtreler
    /// olup olmadığı görünmüyordu; buton üzerinde rozetle gösteriliyor.
    var activeCount: Int {
        let base = DiscoveryFilters()
        var count = 0
        if minimumAge != base.minimumAge || maximumAge != base.maximumAge { count += 1 }
        if !academicYears.isEmpty { count += 1 }
        if !departments.isEmpty { count += 1 }
        if requiresCommonInterest != base.requiresCommonInterest { count += 1 }
        if campusOnly != base.campusOnly { count += 1 }
        return count
    }
}

struct DiscoveryReactionResult: Sendable {
    let matched: Bool
    let matchID: UUID?
}

struct StudentProfile: Identifiable, Hashable {
    let id: UUID
    let name: String
    let age: Int
    let university: String
    let department: String
    let year: String
    let bio: String
    let interests: [String]
    let imageURL: URL?
    let imageAssetName: String?
    let galleryImageURLs: [URL]
    let compatibility: Int
    let isVerified: Bool
    let badge: ProfileBadge
    let compatibilityReasons: [String]
    let relationshipIntent: RelationshipIntent
    let activeLabel: String

    init(id: UUID = UUID(), name: String, age: Int, university: String, department: String, year: String, bio: String, interests: [String], imageURL: URL?, imageAssetName: String? = nil, galleryImageURLs: [URL] = [], compatibility: Int, isVerified: Bool, badge: ProfileBadge = .none, compatibilityReasons: [String] = [], relationshipIntent: RelationshipIntent = .both, activeLabel: String = "Bugün aktif") {
        self.id = id
        self.name = name
        self.age = age
        self.university = university
        self.department = department
        self.year = year
        self.bio = bio
        self.interests = interests
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.galleryImageURLs = galleryImageURLs
        self.compatibility = compatibility
        self.isVerified = isVerified
        self.badge = badge
        self.compatibilityReasons = compatibilityReasons
        self.relationshipIntent = relationshipIntent
        self.activeLabel = activeLabel
    }
}

