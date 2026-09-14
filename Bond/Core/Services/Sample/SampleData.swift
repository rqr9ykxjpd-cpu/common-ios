#if DEBUG
import CryptoKit
import Foundation
import UIKit

// MARK: - Örnek içerik

enum SampleData {
    /// Aynı tohum her açılışta aynı kimliği verir.
    static func stableID(_ seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Örnek kayıtların kimlikleri sabit. Her açılışta yeni UUID üretilseydi
    /// `UserDefaults` her denemede bir hesap anahtarı daha biriktirirdi.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number)) ?? UUID()
    }

    static func date(_ daysAgo: Double) -> Date { .now.addingTimeInterval(-daysAgo * 86_400) }
    static func hours(_ hoursAgo: Double) -> Date { .now.addingTimeInterval(-hoursAgo * 3_600) }

    static let places: [CampusPlace] = [
        CampusPlace(id: id(25), name: "Şamdan Kafe", area: "Merkez Kampüs"),
        CampusPlace(id: id(26), name: "Aytaç Cafe", area: "Merkez Kampüs"),
        CampusPlace(id: id(21), name: "Hazırlık Kantini", area: "Merkez Kampüs"),
        CampusPlace(id: id(27), name: "Otağ", area: "Merkez Kampüs"),
        CampusPlace(id: id(28), name: "Yemekhane", area: "Merkez Kampüs"),
        CampusPlace(id: id(20), name: "Merkez Kütüphane", area: "Merkez Kampüs"),
        CampusPlace(id: id(22), name: "Mühendislik Fakültesi", area: "Merkez Kampüs"),
        CampusPlace(id: id(24), name: "Spor Salonu", area: "Merkez Kampüs")
    ]

    static let me = StudentProfile(
        id: id(1),
        name: "Cem",
        age: 21,
        university: "YÜ",
        department: "Endüstri Mühendisliği",
        year: "3. sınıf",
        bio: "Kampüste kahve içmeyi ve uzun yürüyüşleri seven biri. Hafta sonları sahilde bulunurum.",
        interests: ["Kahve", "Fotoğraf", "Yürüyüş", "Podcast", "Basketbol"],
        imageURL: nil,
        imageAssetName: "profile-berk",
        isVerified: true,
        badge: .founder
    )

    static var myDraft: ProfileDraft {
        var draft = ProfileDraft()
        draft.name = me.name
        draft.birthDate = Calendar.current.date(byAdding: .year, value: -me.age, to: .now) ?? .now
        draft.university = me.university
        draft.department = me.department
        draft.year = me.year
        draft.bio = me.bio
        draft.interests = Set(me.interests)
        // Örnek verideki "ben" kurucu hesabı temsil ediyor; rozet aktarılmayınca
        // kurucuya özel kart görünümü geliştirirken hiç görünmüyordu.
        draft.badge = me.badge
        return draft
    }

    static let profiles: [StudentProfile] = [
        StudentProfile(
            id: id(10),
            name: "Ece", age: 21, university: "YÜ", department: "Görsel İletişim", year: "3. sınıf",
            bio: "Analog fotoğraf çekiyorum, kampüsün her köşesinde bir kare arıyorum.",
            interests: ["Fotoğraf", "Sinema", "Kahve", "Sergi"],
            imageURL: nil, imageAssetName: "profile-ece",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-cafe"),
                UIImageAsset.fileURL(named: "post-quiet")
            ].compactMap { $0 },
            isVerified: true, badge: .moderator
        ),
        StudentProfile(
            id: id(11),
            name: "Defne", age: 20, university: "YÜ", department: "Psikoloji", year: "2. sınıf",
            bio: "Kitap kulübünün en gürültücü üyesi. İyi bir tartışmaya hayır demem.",
            interests: ["Kitap", "Yürüyüş", "Podcast", "Kahve"],
            imageURL: nil, imageAssetName: "profile-defne",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-club"),
                UIImageAsset.fileURL(named: "post-friends")
            ].compactMap { $0 },
            isVerified: true
        ),
        StudentProfile(
            id: id(12),
            name: "Duru", age: 22, university: "YÜ", department: "Mimarlık", year: "4. sınıf",
            bio: "Maket bıçağıyla aram iyi. Sahil yürüyüşü teklif edene hayır demiyorum.",
            interests: ["Tasarım", "Yürüyüş", "Müzik", "Fotoğraf"],
            imageURL: nil, imageAssetName: "profile-duru",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-campus"),
                UIImageAsset.fileURL(named: "post-study")
            ].compactMap { $0 },
            isVerified: false
        ),
        StudentProfile(
            id: id(13),
            name: "Selin", age: 21, university: "YÜ", department: "Hukuk", year: "3. sınıf",
            bio: "Sabah 7 antrenmanı, akşam 7 duruşma provası. Aramda kahve var.",
            interests: ["Koşu", "Kahve", "Münazara"],
            imageURL: nil, imageAssetName: "profile-selin",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-quiet"),
                UIImageAsset.fileURL(named: "post-friends"),
            ].compactMap { $0 },
            isVerified: true
        ),
        StudentProfile(
            id: id(14),
            name: "Mina", age: 20, university: "YÜ", department: "Bilgisayar Mühendisliği", year: "2. sınıf",
            bio: "Gece kodlayan, gündüz uyuyan biri. Bana iyi bir bug getir, arkadaş olalım.",
            interests: ["Yazılım", "Oyun", "Podcast", "Kahve"],
            imageURL: nil, imageAssetName: "profile-mina",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-study"),
                UIImageAsset.fileURL(named: "post-cafe"),
            ].compactMap { $0 },
            isVerified: false
        ),
        StudentProfile(
            id: id(15),
            name: "Arda", age: 23, university: "YÜ", department: "Makine Mühendisliği", year: "4. sınıf",
            bio: "Bisikletle kampüs turu atarım. Motor sesinden anlarım.",
            interests: ["Bisiklet", "Müzik", "Yürüyüş"],
            imageURL: nil, imageAssetName: "profile-arda",
            galleryImageURLs: [
                UIImageAsset.fileURL(named: "post-friends"),
                UIImageAsset.fileURL(named: "post-campus"),
            ].compactMap { $0 },
            isVerified: false
        )
    ]

    static var conversations: [Conversation] {
        let ece = profiles[0]
        let defne = profiles[1]
        return [
            Conversation(
                id: UUID(),
                profile: ece,
                messages: [
                    Message(body: "Selam! Kartındaki kahve muhabbeti dikkatimi çekti 👀", isMine: false, sentAt: hours(5)),
                    Message(body: "Haha yakalandım. Kampüste favori yerin var mı?", isMine: true, sentAt: hours(4.6)),
                    Message(body: "Hazırlık kantini. Işık öğleden sonra çok güzel oluyor, fotoğraf için bire bir.", isMine: false, sentAt: hours(4.2), reaction: "❤️"),
                    Message(body: "O zaman yarın oraya uğrayalım mı?", isMine: true, sentAt: hours(1.1))
                ],
                updatedAt: hours(1.1),
                unreadCount: 0
            ),
            Conversation(
                id: UUID(),
                profile: defne,
                messages: [
                    Message(body: "Kitap kulübüne bu hafta geliyor musun?", isMine: false, sentAt: hours(26)),
                    Message(body: "Hangi kitabı tartışıyorsunuz?", isMine: true, sentAt: hours(25)),
                    Message(body: "Bu ay Türkçe çeviri bir polisiye. Seni de bekleriz!", isMine: false, sentAt: hours(3))
                ],
                updatedAt: hours(3),
                unreadCount: 1
            )
        ]
    }

    static var posts: [BackendPost] {
        [
            post(author: profiles[0], caption: "Ders sonrası planı: kendimizi dışarı atmak.",
                 place: "Hazırlık Kantini", asset: "post-cafe", createdAt: hours(2), likes: 34, liked: true, comments: [
                    ("Defne", "Ben de geliyorum!", 2),
                    ("Mina", "Işık gerçekten güzel olmuş", 5)
                 ]),
            post(author: profiles[4], caption: "Veri Yapıları vizesinde geçen yılki sorular çıkıyor mu? Elinde eski soru olan var mı?",
                 place: nil, asset: nil, createdAt: hours(3.5), likes: 6, liked: false, kind: .question, comments: [
                    ("Arda", "Geçen yıl ağaçlar ve hash ağırlıklıydı, notlarımı atarım", 9),
                    ("Selin", "Hoca bu yıl soruları değiştirdi diye duydum", 3)
                 ]),
            post(author: profiles[5], caption: "Termodinamik ders notlarım (1-8. hafta) PDF olarak hazır. İsteyene DM.",
                 place: nil, asset: nil, createdAt: hours(5), likes: 18, liked: true, kind: .notes, comments: [
                    ("Mina", "Süpersin, mühendislik grubuna da at", 4)
                 ]),
            post(author: profiles[3], caption: "Yarın 09.00'da Hazırlık binasına masa taşıyoruz, iki kişi lazım. Kahve benden.",
                 place: nil, asset: nil, createdAt: hours(6), likes: 8, liked: false, kind: .help, comments: [
                    ("Arda", "Ben varım, 8.45'te oradayım", 3)
                 ]),
            post(author: profiles[4], caption: "Vize haftası kütüphane kampı başladı. İkinci kahve gidiyor.",
                 place: "Merkez Kütüphane", asset: "post-study", createdAt: hours(7), likes: 21, liked: false, comments: [
                    ("Arda", "Dayan, iki gün kaldı", 1)
                 ]),
            post(author: me, caption: "Sahil yürüyüşü her şeye iyi geliyor.",
                 place: "Şamdan Kafe", asset: "post-campus", createdAt: hours(20), likes: 47, liked: false, mine: true, comments: [
                    ("Ece", "Kare çok iyi olmuş", 3),
                    ("Selin", "Yarın da gidelim mi?", 1)
                 ]),
            post(author: profiles[2], caption: "Maket teslimine 6 saat kala bahçede mola.",
                 place: "Otağ", asset: "post-quiet", createdAt: date(1.4), likes: 15, liked: false, comments: []),
            post(author: profiles[1], caption: "Kitap kulübü bu akşam toplanıyor, gelen gelsin.",
                 place: nil, asset: "post-club", createdAt: date(2.1), likes: 29, liked: true, kind: .announcement, comments: [
                    ("Duru", "Saat kaçta?", 2)
                 ]),
            post(author: profiles[3], caption: "Sabah koşusu bitti, güne 1-0 öndeyim.",
                 place: nil, asset: "post-friends", createdAt: date(3), likes: 38, liked: false, comments: [])
        ]
    }

    private static func post(
        author: StudentProfile, caption: String, place: String?, asset: String?,
        createdAt: Date, likes: Int, liked: Bool, mine: Bool = false, kind: PostKind = .moment,
        comments: [(String, String, Int)]
    ) -> BackendPost {
        // Kimlik açılışlar arasında sabit: "görüldü" sayacı ve kaydedilenler
        // örnek modda da çalışsın.
        let postID = stableID("post:" + caption)
        return BackendPost(
            id: postID,
            authorID: author.id,
            authorName: author.name,
            authorBirthDate: Calendar.current.date(byAdding: .year, value: -author.age, to: .now) ?? .now,
            authorUniversity: author.university,
            authorDepartment: author.department,
            authorYear: author.year,
            authorBio: author.bio,
            authorVerified: author.isVerified,
            authorBadge: author.badge,
            authorAvatarURL: author.imageAssetName.flatMap(UIImageAsset.fileURL(named:)),
            caption: caption,
            placeName: place,
            kind: kind,
            imageData: asset.flatMap(UIImageAsset.data(named:)),
            createdAt: createdAt,
            comments: comments.map { name, body, votes in
                BackendComment(id: UUID(), postID: postID, authorID: UUID(), authorName: name, authorAvatarURL: nil, body: body, createdAt: createdAt, voteCount: votes)
            },
            likeCount: likes,
            liked: liked,
            saved: false
        )
    }

    static func newPost(caption: String, placeName: String?, imageData: Data?, kind: PostKind = .moment) -> BackendPost {
        BackendPost(
            id: UUID(), authorID: me.id, authorName: me.name,
            authorBirthDate: Calendar.current.date(byAdding: .year, value: -me.age, to: .now) ?? .now,
            authorUniversity: me.university, authorDepartment: me.department, authorYear: me.year,
            authorBio: me.bio, authorVerified: me.isVerified, authorBadge: me.badge,
            authorAvatarURL: me.imageAssetName.flatMap(UIImageAsset.fileURL(named:)),
            caption: caption, placeName: placeName, kind: kind, imageData: imageData, createdAt: .now,
            comments: [], likeCount: 0, liked: false, saved: false
        )
    }

    static var notifications: [BackendNotification] {
        [
            BackendNotification(id: UUID(), kind: .match, title: "Yeni eşleşme",
                                body: "Ece ile denk geldiniz.", actorID: profiles[0].id, actorName: "Ece",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-ece"), matchID: nil, isRead: false, createdAt: hours(5.4)),
            BackendNotification(id: UUID(), kind: .message, title: "Yeni mesaj",
                                body: "Defne: Seni de bekleriz!", actorID: profiles[1].id, actorName: "Defne",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-defne"), matchID: nil, isRead: false, createdAt: hours(3)),
            BackendNotification(id: UUID(), kind: .like, title: "Sizi biri sağa kaydırdı",
                                body: "Duru kartını sağa kaydırdı.", actorID: profiles[2].id, actorName: "Duru",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-duru"), matchID: nil, isRead: false, createdAt: hours(1.2)),
            BackendNotification(id: UUID(), kind: .like, title: "Gönderini beğendi",
                                body: "Selin sahil paylaşımını beğendi.", actorID: profiles[3].id, actorName: "Selin",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-selin"), matchID: nil, isRead: true, createdAt: hours(19)),
            BackendNotification(id: UUID(), kind: .comment, title: "Gönderine yorum",
                                body: "Ece: Kare çok iyi olmuş", actorID: profiles[0].id, actorName: "Ece",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-ece"), matchID: nil, isRead: true, createdAt: hours(19.5)),
            BackendNotification(id: UUID(), kind: .meetingRequest, title: "Buluşma isteği",
                                body: "Mina, Merkez Kütüphane'de buluşmak istiyor.", actorID: profiles[4].id, actorName: "Mina",
                                actorAvatarURL: UIImageAsset.fileURL(named: "profile-mina"), matchID: nil, isRead: false, createdAt: date(1.2))
        ]
    }

    static func stories(places: [CampusPlace]) -> [CampusStory] {
        [
            CampusStory(author: me, imageAssetName: "post-campus", caption: "Sabah kampüsü",
                        place: places[0], viewed: false,
                        viewRecords: [
                            StoryViewRecord(viewer: profiles[0], viewCount: 2, lastViewedAt: hours(1)),
                            StoryViewRecord(viewer: profiles[4], viewCount: 1, lastViewedAt: hours(3))
                        ],
                        isMine: true),
            CampusStory(author: profiles[0], imageAssetName: "post-cafe", caption: "Bugünün ışığı",
                        place: places[1], viewed: false),
            CampusStory(author: profiles[4], imageAssetName: "post-study", caption: "Vize kampı 2. gün",
                        place: places[0], viewed: true)
        ]
    }

    static func clubs(places: [CampusPlace]) -> [CampusClub] {
        [
            CampusClub(id: id(30), name: "Fotoğraf Kulübü", summary: "Haftada bir kampüs turu, ayda bir sergi.",
                       icon: "camera.fill", memberCount: 128, nextEvent: "Gece çekimi — Perşembe 20.00",
                       meetingPlace: places[2], accentHex: "8066FF"),
            CampusClub(id: id(31), name: "Kitap Kulübü", summary: "Ayda bir kitap, sonunda uzun bir tartışma.",
                       icon: "book.fill", memberCount: 76, nextEvent: "Aylık toplantı — Salı 18.30",
                       meetingPlace: places[0], accentHex: "FF745E"),
            CampusClub(id: id(32), name: "Dağcılık ve Doğa", summary: "Hafta sonu rotaları, kamp ve tırmanış.",
                       icon: "figure.hiking", memberCount: 54, nextEvent: "Sahil yürüyüşü — Cumartesi 09.00",
                       meetingPlace: places[3], accentHex: "2E9E5B"),
            CampusClub(id: id(33), name: "Yazılım Topluluğu", summary: "Proje geceleri ve birlikte öğrenme.",
                       icon: "chevron.left.forwardslash.chevron.right", memberCount: 193, nextEvent: "Proje gecesi — Çarşamba 19.00",
                       meetingPlace: places[0], accentHex: "0F7FB8")
        ]
    }

    static func meetingRequests(places: [CampusPlace]) -> [MeetingRequest] {
        [
            MeetingRequest(profile: profiles[4], place: places[0], direction: .incoming, status: .pending, createdAt: date(1.2)),
            MeetingRequest(profile: profiles[1], place: places[1], direction: .outgoing, status: .accepted, createdAt: date(2.5)),
            MeetingRequest(profile: profiles[3], place: places[4], direction: .incoming, status: .declined, createdAt: date(4))
        ]
    }

    /// Biri adsız: gizlilik kuralı yüzünden profili okunamayan engelli
    /// kullanıcının listede nasıl göründüğünü örnek veriyle de görebilelim.
    static var blockedProfiles: [BlockedProfile] {
        [
            BlockedProfile(id: profiles[3].id, name: profiles[3].name,
                           imageURL: profiles[3].imageURL, blockedAt: hours(30)),
            BlockedProfile(id: id(91), name: nil, imageURL: nil, blockedAt: date(6))
        ]
    }

    static var reports: [ModerationReport] {
        [
            ModerationReport(id: UUID(), reporter: profiles[0], reported: profiles[3],
                             reason: .harassment, details: "Sohbette ısrarcı davrandı, engelledim ama başka hesaptan yazdı.",
                             createdAt: hours(4), handledAt: nil, resolution: nil, reportedActive: true),
            ModerationReport(id: UUID(), reporter: profiles[4], reported: profiles[1],
                             reason: .spam, details: nil,
                             createdAt: date(1.3), handledAt: nil, resolution: nil, reportedActive: true)
        ]
    }

    static var messageRequests: [MessageRequest] {
        [
            MessageRequest(id: UUID(), profile: profiles[2],
                           body: "Selam! Story'deki kütüphane köşesi neresi? Ben de sessiz bir yer arıyorum.",
                           direction: .incoming, status: .pending, createdAt: hours(3)),
            MessageRequest(id: UUID(), profile: profiles[0],
                           body: "Fotoğraf kulübüne sen de mi gidiyorsun?",
                           direction: .incoming, status: .pending, createdAt: date(1.1))
        ]
    }

    static var visits: [ProfileVisit] {
        [
            ProfileVisit(profile: profiles[0], visitedAt: hours(2)),
            ProfileVisit(profile: profiles[4], visitedAt: hours(9)),
            ProfileVisit(profile: profiles[2], visitedAt: date(1.5)),
            ProfileVisit(profile: profiles[3], visitedAt: date(4.2))
        ]
    }
}

/// Örnek görseller paketteki asset'lerden okunuyor.
///
/// `BackendPost` ham `Data` beklediği için gönderi görselleri JPEG'e çevriliyor.
/// Avatar tarafında ise model yalnızca `URL` taşıyor — asset adı taşımıyor — bu
/// yüzden görsel bir kez geçici dizine yazılıp `file://` adresi veriliyor.
/// Böylece örnek akış gerçek akışla aynı yolu (`AsyncImage`) kullanıyor.
private enum UIImageAsset {
    static func data(named: String) -> Data? {
        UIImage(named: named)?.jpegData(compressionQuality: 0.8)
    }

    private static let directory: URL = {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("CampusSample", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static func fileURL(named: String) -> URL? {
        let url = directory.appendingPathComponent("\(named).jpg")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        guard let data = data(named: named) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

#endif
