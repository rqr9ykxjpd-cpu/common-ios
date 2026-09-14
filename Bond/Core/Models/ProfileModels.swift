import SwiftUI
/// Profilde görünen işaret.
///
/// Daha önce mavi tik `is_verified` alanından geliyordu — ama o alan aynı zamanda
/// listede görünme kapısıydı ve herkeste açık olmak zorunda. Yani tik herkeste
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

    /// Rozet zemini. Kurucu, moderatörle aynı görünmemeli: ikisi de aynı yeşil
    /// kapsülken "kurucu" olmanın ayırt edici bir yanı kalmıyordu.
    var accent: Color {
        switch self {
        case .none: .clear
        case .verified: BondTheme.violet
        case .moderator: BondTheme.violet
        case .founder: BondTheme.ember
        }
    }

    /// Üç zemin de koyu ya da doygun; üstlerine beyaz gidiyor.
    var accentForeground: Color { .white }

    var systemImage: String? {
        switch self {
        case .none: nil
        case .verified: "checkmark.seal.fill"
        case .moderator: "shield.lefthalf.filled"
        case .founder: "star.circle.fill"
        }
    }

    /// Yalnızca profil ekranlarında, rozetin altında görünen ikinci satır.
    /// Akış ve listelerde gösterilmiyor: oralarda satır yüksekliğini bozar.
    var subtitle: String? {
        switch self {
        case .founder: L10n.Badge.founderSubtitle
        case .none, .verified, .moderator: nil
        }
    }

    /// Profil ekranında rozetin yanında yazan açıklama.
    var title: String? {
        switch self {
        case .none: nil
        case .verified: L10n.Badge.verified
        case .moderator: L10n.Badge.moderator
        case .founder: L10n.Badge.founder
        }
    }
}

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
    let galleryImageURLs: [URL]
    let isVerified: Bool
    let badge: ProfileBadge
    /// Kampüste şu an görünür olduğu yer. Dizin kartı için; yoksa nil.
    let visiblePlaceID: UUID?

    init(id: UUID = UUID(), name: String, age: Int, university: String, department: String, year: String, bio: String, interests: [String], imageURL: URL?, imageAssetName: String? = nil, galleryImageURLs: [URL] = [], isVerified: Bool, badge: ProfileBadge = .none, visiblePlaceID: UUID? = nil) {
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
        self.isVerified = isVerified
        self.badge = badge
        self.visiblePlaceID = visiblePlaceID
    }

    /// Profil satırı okunamayan izleyici. Sayı yine dursun, isim sonradan dolar.
    static func anonymousViewer(id: UUID) -> StudentProfile {
        StudentProfile(
            id: id, name: L10n.Common.someone, age: 18, university: "", department: "",
            year: "", bio: "", interests: [], imageURL: nil, isVerified: false
        )
    }

    /// Aynı profili farklı rozetle kopyalar (akış / story yüklemesinde yerel yedek).
    func withBadge(_ badge: ProfileBadge) -> StudentProfile {
        guard badge != self.badge else { return self }
        return StudentProfile(
            id: id, name: name, age: age, university: university, department: department,
            year: year, bio: bio, interests: interests, imageURL: imageURL,
            imageAssetName: imageAssetName, galleryImageURLs: galleryImageURLs,
            isVerified: isVerified, badge: badge, visiblePlaceID: visiblePlaceID
        )
    }
}

/// Engellenen bir kişi.
///
/// Ad ve fotoğraf isteğe bağlı: gizlilik kuralı "engellediğim kişi"yi
/// görünür kılmıyor, dolayısıyla ortak bir gönderi/eşleşme yoksa profil satırı
/// okunamayabiliyor. O durumda listede yalnızca tarih ve engeli kaldırma
/// düğmesi kalıyor — kimliği okuyamamak, engeli kaldıramamak için sebep değil.
struct BlockedProfile: Identifiable, Hashable {
    let id: UUID
    let name: String?
    let imageURL: URL?
    let blockedAt: Date
}

