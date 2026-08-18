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
    let compatibilityReasons: [String]
    let relationshipIntent: RelationshipIntent
    let activeLabel: String

    init(id: UUID = UUID(), name: String, age: Int, university: String, department: String, year: String, bio: String, interests: [String], imageURL: URL?, imageAssetName: String? = nil, galleryImageURLs: [URL] = [], compatibility: Int, isVerified: Bool, compatibilityReasons: [String] = [], relationshipIntent: RelationshipIntent = .both, activeLabel: String = "Bugün aktif") {
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
        self.compatibilityReasons = compatibilityReasons
        self.relationshipIntent = relationshipIntent
        self.activeLabel = activeLabel
    }
}

