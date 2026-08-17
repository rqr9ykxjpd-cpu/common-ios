import Foundation

struct CampusPlace: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let area: String

    init(id: UUID = UUID(), name: String, area: String) {
        self.id = id
        self.name = name
        self.area = area
    }

    static let samples = [
        CampusPlace(name: "Hazırlık Kantini", area: "YÜ"),
        CampusPlace(name: "Şamdan Kafe", area: "Yalova"),
        CampusPlace(name: "Otağ", area: "Merkez Kampüs"),
        CampusPlace(name: "İİBF", area: "Merkez Kampüs"),
        CampusPlace(name: "Merkez Kütüphane", area: "Merkez Kampüs")
    ]
}

private enum YalovaSocialProfiles {
    static let all: [StudentProfile] = [
        StudentProfile(name: "Defne", age: 22, university: "YÜ", department: "Psikoloji", year: "3. sınıf", bio: "Kahve, müzik ve plansız kampüs molaları.", interests: ["Kahve", "Müzik", "Fotoğraf"], imageURL: nil, imageAssetName: "profile-defne", compatibility: 94, isVerified: true),
        StudentProfile(name: "Ece", age: 21, university: "YÜ", department: "Endüstri Mühendisliği", year: "3. sınıf", bio: "Ders aralarında kahve ve sahil planları.", interests: ["Koşu", "Müzik", "Kahve"], imageURL: nil, imageAssetName: "profile-ece", compatibility: 89, isVerified: true),
        StudentProfile(name: "Mina", age: 23, university: "YÜ", department: "İşletme", year: "4. sınıf", bio: "Kısa filmler ve uzun sohbetler.", interests: ["Sinema", "Tasarım", "Pilates"], imageURL: nil, imageAssetName: "profile-mina", compatibility: 86, isVerified: true),
        StudentProfile(name: "Duru", age: 20, university: "YÜ", department: "Hukuk", year: "2. sınıf", bio: "Kitap, tiyatro ve kampüs yürüyüşleri.", interests: ["Tiyatro", "Kitap", "Sahil"], imageURL: nil, imageAssetName: "profile-duru", compatibility: 83, isVerified: true),
        StudentProfile(name: "Berk", age: 22, university: "YÜ", department: "Uluslararası İlişkiler", year: "3. sınıf", bio: "Basketbol, konser ve yeni kahveciler.", interests: ["Basketbol", "Konser", "Gezi"], imageURL: nil, imageAssetName: "profile-berk", compatibility: 81, isVerified: true),
        StudentProfile(name: "Selin", age: 21, university: "YÜ", department: "Sosyal Hizmet", year: "2. sınıf", bio: "Fotoğraf çekmeyi ve sakin yerleri seviyorum.", interests: ["Fotoğraf", "Kahve", "Doğa"], imageURL: nil, imageAssetName: "profile-selin", compatibility: 79, isVerified: true),
        StudentProfile(name: "Arda", age: 23, university: "YÜ", department: "Bilgisayar Mühendisliği", year: "4. sınıf", bio: "Teknoloji kulübü, masa oyunları ve filtre kahve.", interests: ["Teknoloji", "Oyun", "Kahve"], imageURL: nil, imageAssetName: "profile-arda", compatibility: 78, isVerified: true)
    ]
}

extension StudentProfile {
    var visiblePlace: CampusPlace? {
        switch name {
        case "Ece", "Berk": CampusPlace.samples[1]
        case "Mina", "Arda": CampusPlace.samples[2]
        case "Duru": CampusPlace.samples[3]
        case "Defne", "Selin": CampusPlace.samples[0]
        default: nil
        }
    }
}

extension CampusPlace {
    var activeProfiles: [StudentProfile] {
        switch name {
        case "Şamdan Kafe":
            return [YalovaSocialProfiles.all[1], YalovaSocialProfiles.all[2], YalovaSocialProfiles.all[4]]
        case "Hazırlık Kantini":
            return [YalovaSocialProfiles.all[0], YalovaSocialProfiles.all[5]]
        case "Otağ":
            return [YalovaSocialProfiles.all[2], YalovaSocialProfiles.all[6]]
        case "İİBF":
            return [YalovaSocialProfiles.all[3], YalovaSocialProfiles.all[4]]
        default:
            return [YalovaSocialProfiles.all[0], YalovaSocialProfiles.all[6]]
        }
    }
}

struct CampusClub: Identifiable, Hashable {
    let id: UUID
    let name: String
    let summary: String
    let icon: String
    let memberCount: Int
    let nextEvent: String
    let meetingPlace: CampusPlace?
    let accentHex: String

    init(id: UUID = UUID(), name: String, summary: String, icon: String, memberCount: Int, nextEvent: String, meetingPlace: CampusPlace?, accentHex: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.icon = icon
        self.memberCount = memberCount
        self.nextEvent = nextEvent
        self.meetingPlace = meetingPlace
        self.accentHex = accentHex
    }

    static let samples: [CampusClub] = [
        CampusClub(
            name: "Sürdürülebilirlik Kulübü",
            summary: "YÜ kampüsünde daha az atık, daha çok dayanışma ve uygulanabilir çevre fikirleri.",
            icon: "leaf.fill",
            memberCount: 128,
            nextEvent: "Çarşamba · 17.30 · Otağ",
            meetingPlace: CampusPlace.samples[2],
            accentHex: "62C98D"
        ),
        CampusClub(
            name: "Fotoğraf Topluluğu",
            summary: "Kampüs yürüyüşleri, analog kareler ve aylık açık sergiler.",
            icon: "camera.fill",
            memberCount: 84,
            nextEvent: "Cuma · 16.00 · İİBF",
            meetingPlace: CampusPlace.samples[3],
            accentHex: "8B6CF6"
        ),
        CampusClub(
            name: "Müzik Kulübü",
            summary: "Jam buluşmaları, kampüs sahnesi ve birlikte hazırlanan çalma listeleri.",
            icon: "music.note",
            memberCount: 156,
            nextEvent: "Perşembe · 19.00 · Şamdan Kafe",
            meetingPlace: CampusPlace.samples[1],
            accentHex: "FF7A72"
        )
    ]
}

struct SocialComment: Identifiable, Hashable {
    let id: UUID
    let author: String
    let body: String
    let isMine: Bool
    let createdAt: Date

    init(id: UUID = UUID(), author: String, body: String, isMine: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.body = body
        self.isMine = isMine
        self.createdAt = createdAt
    }
}

struct SocialPost: Identifiable, Hashable {
    let id: UUID
    let author: StudentProfile
    var caption: String
    var imageURL: URL?
    var imageAssetName: String?
    var localImageData: Data?
    var place: CampusPlace?
    var liked: Bool
    var saved: Bool
    var isMine: Bool
    var likeCount: Int
    var comments: [SocialComment]
    let createdAt: Date

    init(id: UUID = UUID(), author: StudentProfile, caption: String, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, place: CampusPlace? = nil, liked: Bool = false, saved: Bool = false, isMine: Bool = false, likeCount: Int, comments: [SocialComment] = [], createdAt: Date = .now) {
        self.id = id
        self.author = author
        self.caption = caption
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.localImageData = localImageData
        self.place = place
        self.liked = liked
        self.saved = saved
        self.isMine = isMine
        self.likeCount = likeCount
        self.comments = comments
        self.createdAt = createdAt
    }

    static let samples: [SocialPost] = [
        SocialPost(author: YalovaSocialProfiles.all[0], caption: "Ders çıkışı kantinde kısa bir kahve molası.", imageAssetName: "post-study", place: CampusPlace.samples[0], likeCount: 42, comments: [.init(author: "Ece", body: "Bir dahaki molaya geliyorum")], createdAt: .now.addingTimeInterval(-1400)),
        SocialPost(author: YalovaSocialProfiles.all[1], caption: "Ders öncesi Şamdan'da buluşan var mı?", imageAssetName: "post-cafe", place: CampusPlace.samples[1], likeCount: 67, comments: [.init(author: "Mina", body: "Yarım saate oradayım")], createdAt: .now.addingTimeInterval(-5100)),
        SocialPost(author: YalovaSocialProfiles.all[2], caption: "Bu haftanın kulüp buluşması için hazırlıklar başladı.", imageAssetName: "post-club", place: CampusPlace.samples[2], likeCount: 31, createdAt: .now.addingTimeInterval(-9600))
    ]
}

struct StoryViewRecord: Identifiable, Hashable {
    let id: UUID
    let viewer: StudentProfile
    var viewCount: Int
    var lastViewedAt: Date

    init(id: UUID = UUID(), viewer: StudentProfile, viewCount: Int, lastViewedAt: Date = .now) {
        self.id = id
        self.viewer = viewer
        self.viewCount = viewCount
        self.lastViewedAt = lastViewedAt
    }
}

struct CampusStory: Identifiable, Hashable {
    let id: UUID
    let author: StudentProfile
    let imageURL: URL?
    let imageAssetName: String?
    let localImageData: Data?
    let caption: String
    let place: CampusPlace?
    var viewed: Bool
    var viewRecords: [StoryViewRecord]
    var isMine: Bool
    let expiresAt: Date

    init(id: UUID = UUID(), author: StudentProfile, imageURL: URL? = nil, imageAssetName: String? = nil, localImageData: Data? = nil, caption: String, place: CampusPlace? = nil, viewed: Bool = false, viewRecords: [StoryViewRecord] = [], isMine: Bool = false, expiresAt: Date = .now.addingTimeInterval(86_400)) {
        self.id = id
        self.author = author
        self.imageURL = imageURL
        self.imageAssetName = imageAssetName
        self.localImageData = localImageData
        self.caption = caption
        self.place = place
        self.viewed = viewed
        self.viewRecords = viewRecords
        self.isMine = isMine
        self.expiresAt = expiresAt
    }

    static let samples: [CampusStory] = [
        CampusStory(
            author: YalovaSocialProfiles.all[0],
            imageAssetName: "post-study",
            caption: "Hazırlık sonrası mola",
            place: CampusPlace.samples[0],
            viewRecords: [
                StoryViewRecord(viewer: YalovaSocialProfiles.all[1], viewCount: 2, lastViewedAt: .now.addingTimeInterval(-420)),
                StoryViewRecord(viewer: YalovaSocialProfiles.all[2], viewCount: 1, lastViewedAt: .now.addingTimeInterval(-900))
            ]
        ),
        CampusStory(
            author: YalovaSocialProfiles.all[1],
            imageAssetName: "post-cafe",
            caption: "Şamdan'da kahve molası",
            place: CampusPlace.samples[1],
            viewRecords: [
                StoryViewRecord(viewer: YalovaSocialProfiles.all[0], viewCount: 3, lastViewedAt: .now.addingTimeInterval(-240)),
                StoryViewRecord(viewer: YalovaSocialProfiles.all[2], viewCount: 1, lastViewedAt: .now.addingTimeInterval(-1_200))
            ]
        ),
        CampusStory(
            author: YalovaSocialProfiles.all[2],
            imageAssetName: "post-club",
            caption: "Bu akşam buradayız",
            place: CampusPlace.samples[2],
            viewRecords: [
                StoryViewRecord(viewer: YalovaSocialProfiles.all[0], viewCount: 2, lastViewedAt: .now.addingTimeInterval(-600)),
                StoryViewRecord(viewer: YalovaSocialProfiles.all[1], viewCount: 4, lastViewedAt: .now.addingTimeInterval(-180))
            ]
        )
    ]
}

struct ProfileVisit: Identifiable, Hashable {
    let id = UUID()
    let profile: StudentProfile
    let visitedAt: Date

    static let samples = [
        ProfileVisit(profile: StudentProfile.samples[1], visitedAt: .now.addingTimeInterval(-600)),
        ProfileVisit(profile: StudentProfile.samples[2], visitedAt: .now.addingTimeInterval(-3_800)),
        ProfileVisit(profile: StudentProfile.samples[0], visitedAt: .now.addingTimeInterval(-80_000))
    ]
}
