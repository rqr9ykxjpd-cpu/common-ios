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

struct ProfilePrompt: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var answer: String

    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

struct DiscoveryFilters: Equatable, Codable {
    var minimumAge = 18
    var maximumAge = 30
    var academicYears: Set<String> = []
    var departments: Set<String> = []
    var requiresCommonInterest = false
    var campusOnly = true
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
    let prompts: [ProfilePrompt]
    let relationshipIntent: RelationshipIntent
    let activeLabel: String

    init(id: UUID = UUID(), name: String, age: Int, university: String, department: String, year: String, bio: String, interests: [String], imageURL: URL?, imageAssetName: String? = nil, galleryImageURLs: [URL] = [], compatibility: Int, isVerified: Bool, compatibilityReasons: [String] = [], prompts: [ProfilePrompt] = [], relationshipIntent: RelationshipIntent = .both, activeLabel: String = "Bugün aktif") {
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
        self.prompts = prompts
        self.relationshipIntent = relationshipIntent
        self.activeLabel = activeLabel
    }
}

extension StudentProfile {
    var galleryAssetNames: [String] {
        switch name {
        case "Defne": ["profile-defne", "post-study", "post-quiet"]
        case "Ece": ["profile-ece", "post-cafe", "post-friends"]
        case "Mina": ["profile-mina", "post-club", "post-campus"]
        default: imageAssetName.map { [$0] } ?? []
        }
    }

    static let samples: [StudentProfile] = [
        .init(name: "Defne", age: 22, university: "YÜ", department: "Psikoloji", year: "3. sınıf", bio: "Gece yürüyüşleri, iyi kahve ve kampüste plansız karşılaşmalar.", interests: ["Analog", "Indie", "Sergiler"], imageURL: nil, imageAssetName: "profile-defne", compatibility: 94, isVerified: true, compatibilityReasons: ["2 ortak ilgi alanı", "Tanışma niyetiniz benzer"], prompts: [.init(question: "Kampüste beni nerede bulursun?", answer: "Kütüphane çıkışı kahve ararken."), .init(question: "Plansız bir akşam", answer: "Sahil yürüyüşü ve iyi bir playlist.")], relationshipIntent: .both, activeLabel: "Yakın zamanda aktif"),
        .init(name: "Ece", age: 21, university: "YÜ", department: "Endüstri Mühendisliği", year: "3. sınıf", bio: "Ders aralarında kahve, hafta sonu sahil ve canlı müzik planlarına varım.", interests: ["Müzik", "Kahve", "Koşu"], imageURL: nil, imageAssetName: "profile-ece", compatibility: 89, isVerified: true, compatibilityReasons: ["Kahve ortak ilginiz", "Aynı sınıf düzeyi"], prompts: [.init(question: "İlk buluşma fikrim", answer: "Kısa kahve, uzun sohbet."), .init(question: "Beni güldüren şey", answer: "Kötü kelime oyunları.")], relationshipIntent: .dating, activeLabel: "Bugün aktif"),
        .init(name: "Mina", age: 23, university: "YÜ", department: "İşletme", year: "4. sınıf", bio: "Kısa filmler çekiyorum, uzun sohbetleri seviyorum. Kampüste yeni insanlar tanımaya açığım.", interests: ["Sinema", "Tasarım", "Pilates"], imageURL: nil, imageAssetName: "profile-mina", compatibility: 86, isVerified: true, compatibilityReasons: ["Yaratıcı etkinlikleri seviyorsunuz"], prompts: [.init(question: "Beraber deneyelim", answer: "Kampüste bir kısa film çekmek."), .init(question: "Pazar ritüelim", answer: "Kahve ve eski filmler.")], relationshipIntent: .friendship, activeLabel: "Bu hafta aktif")
    ]
}
