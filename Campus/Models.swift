import Foundation

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
    let compatibility: Int
    let isVerified: Bool

    init(id: UUID = UUID(), name: String, age: Int, university: String, department: String, year: String, bio: String, interests: [String], imageURL: URL?, imageAssetName: String? = nil, compatibility: Int, isVerified: Bool) {
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
        self.compatibility = compatibility
        self.isVerified = isVerified
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
        .init(name: "Defne", age: 22, university: "YÜ", department: "Psikoloji", year: "3. sınıf", bio: "Gece yürüyüşleri, iyi kahve ve kampüste plansız karşılaşmalar.", interests: ["Analog", "Indie", "Sergiler"], imageURL: nil, imageAssetName: "profile-defne", compatibility: 94, isVerified: true),
        .init(name: "Ece", age: 21, university: "YÜ", department: "Endüstri Mühendisliği", year: "3. sınıf", bio: "Ders aralarında kahve, hafta sonu sahil ve canlı müzik planlarına varım.", interests: ["Müzik", "Kahve", "Koşu"], imageURL: nil, imageAssetName: "profile-ece", compatibility: 89, isVerified: true),
        .init(name: "Mina", age: 23, university: "YÜ", department: "İşletme", year: "4. sınıf", bio: "Kısa filmler çekiyorum, uzun sohbetleri seviyorum. Kampüste yeni insanlar tanımaya açığım.", interests: ["Sinema", "Tasarım", "Pilates"], imageURL: nil, imageAssetName: "profile-mina", compatibility: 86, isVerified: true)
    ]
}
