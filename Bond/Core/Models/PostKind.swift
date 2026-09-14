import SwiftUI
import UIKit

/// Gönderi rozeti. Ham değerler sunucudaki `posts.kind` sütunuyla birebir aynı
/// (kısıt: 20260914070000_badge_catalog.sql). `moment` = rozet seçilmemiş; yeni
/// gönderide rozet zorunlu, `moment` yalnızca eski satırlar ve bilinmeyen değerler
/// için kalır. Sıra = katalog sırası; `featured` çip sırasında görünenler.
enum PostKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case moment
    // Kampüs
    case question
    case announcement
    case notes
    case help
    case event
    case poll
    case agenda
    // İlgi alanları
    case sports
    case music
    case film
    case games
    case food
    case art
    case literature
    case science
    case nature
    case health
    case history
    case philosophy
    case culture
    // Biçim
    case photo
    case lifeStory = "life_story"
    case instant
    case serious
    case flood
    // Topluluk (referans listeden aynen)
    case agaBeee = "aga_beee"
    case bele
    case ahraz

    var id: String { rawValue }

    /// Seçilebilir rozetler; `moment` katalogda yok.
    static var catalog: [PostKind] { allCases.filter { $0 != .moment } }
    /// Akış filtresi ve sıralama için rozetli türler (katalogla aynı).
    static var tagged: [PostKind] { catalog }
    /// Çip sırasında öne çıkanlar; gerisi "Daha fazla…" kataloğunda.
    static let featured: [PostKind] = [.question, .announcement, .notes, .help, .event, .agenda]

    var title: String {
        switch self {
        case .moment: L10n.PostKind.moment
        case .question: L10n.PostKind.question
        case .announcement: L10n.PostKind.announcement
        case .notes: L10n.PostKind.notes
        default: L10n.PostKind.title(rawValue)
        }
    }

    /// Referans listedeki emoji; varsa çipte/rozette SF ikon yerine bu görünür.
    var emoji: String? {
        switch self {
        case .food: "🍜"
        case .help: "🫧"
        case .science: "⚛️"
        case .nature: "🌲"
        case .health: "💉"
        case .art: "🎨"
        case .agenda: "🌐"
        case .literature: "📜"
        case .poll: "❓"
        case .agaBeee: "🚬"
        default: nil
        }
    }

    /// Referans listede resim olan rozetler: Assets'teki görsel adı. Görsel
    /// gelene kadar rozet yalnızca adıyla görünür (emoji koyulmaz).
    var imageAssetName: String? {
        switch self {
        case .philosophy: "badge-felsefe"
        default: nil
        }
    }

    /// Asset paketteyse görsel; yoksa nil (adı yalnız kalır).
    var image: UIImage? {
        imageAssetName.flatMap(UIImage.init(named:))
    }

    /// Katalog kapsülünde görünen ad: başlık + emoji ("Yemek 🍜"); resimli
    /// rozetlerde resim ayrı çizilir.
    var displayTitle: String {
        guard let emoji else { return title }
        return "\(title) \(emoji)"
    }

    /// Katalogdaki tek satırlık açıklama.
    var description: String {
        switch self {
        case .moment: L10n.PostKind.catalogNone
        default: L10n.PostKind.description(rawValue)
        }
    }

    var systemImage: String {
        switch self {
        case .moment: "photo.on.rectangle"
        case .question: "questionmark.bubble"
        case .announcement: "megaphone"
        case .notes: "doc.text"
        case .help: "hand.raised"
        case .event: "calendar"
        case .poll: "chart.bar"
        case .agenda: "globe"
        case .sports: "figure.run"
        case .music: "music.note"
        case .film: "film"
        case .games: "gamecontroller"
        case .food: "fork.knife"
        case .art: "paintpalette"
        case .literature: "book"
        case .science: "atom"
        case .nature: "leaf"
        case .health: "cross.case"
        case .history: "building.columns"
        case .philosophy: "brain.head.profile"
        case .culture: "lightbulb"
        case .photo: "photo"
        case .lifeStory: "quote.bubble"
        case .instant: "bolt"
        case .serious: "exclamationmark.triangle"
        case .flood: "text.line.first.and.arrowtriangle.forward"
        case .agaBeee: "face.smiling"
        case .bele: "quote.opening"
        case .ahraz: "questionmark.circle"
        }
    }

    /// Rozet rengi (açık/koyu). Rozette %12 zemin + tam ton; çipte dolgu.
    var tint: Color {
        switch self {
        case .moment: BondTheme.ink
        case .question: BondTheme.tintQuestion
        case .announcement: BondTheme.tintAnnouncement
        case .notes: BondTheme.tintNotes
        case .help: BondTheme.badgeTint(light: "EA580C", dark: "FB923C")
        case .event: BondTheme.badgeTint(light: "7C3AED", dark: "A78BFA")
        case .poll: BondTheme.badgeTint(light: "0284C7", dark: "38BDF8")
        case .agenda: BondTheme.badgeTint(light: "6B7280", dark: "9CA3AF")
        case .sports: BondTheme.badgeTint(light: "EA580C", dark: "FB923C")
        case .music: BondTheme.badgeTint(light: "2563EB", dark: "60A5FA")
        case .film: BondTheme.badgeTint(light: "1E3A8A", dark: "818CF8")
        case .games: BondTheme.badgeTint(light: "4F46E5", dark: "818CF8")
        case .food: BondTheme.badgeTint(light: "0891B2", dark: "22D3EE")
        case .art: BondTheme.badgeTint(light: "6B7280", dark: "9CA3AF")
        case .literature: BondTheme.badgeTint(light: "C2410C", dark: "FB923C")
        case .science: BondTheme.badgeTint(light: "0369A1", dark: "38BDF8")
        case .nature: BondTheme.badgeTint(light: "16A34A", dark: "4ADE80")
        case .health: BondTheme.badgeTint(light: "0284C7", dark: "38BDF8")
        case .history: BondTheme.badgeTint(light: "8A7A45", dark: "C9B36A")
        case .philosophy: BondTheme.badgeTint(light: "9A6B2F", dark: "C89B5A")
        case .culture: BondTheme.badgeTint(light: "1D4ED8", dark: "60A5FA")
        case .photo: BondTheme.badgeTint(light: "737373", dark: "A3A3A3")
        case .lifeStory: BondTheme.badgeTint(light: "B45309", dark: "D97706")
        case .instant: BondTheme.badgeTint(light: "9333EA", dark: "C084FC")
        case .serious: BondTheme.badgeTint(light: "B91C1C", dark: "F87171")
        case .flood: BondTheme.badgeTint(light: "D97706", dark: "FBBF24")
        case .agaBeee: BondTheme.badgeTint(light: "DC2626", dark: "F87171")
        case .bele: BondTheme.badgeTint(light: "0891B2", dark: "22D3EE")
        case .ahraz: BondTheme.badgeTint(light: "5F8F8B", dark: "8FBFBB")
        }
    }

    /// Composer'daki metin alanının yer tutucusu.
    var placeholder: String {
        switch self {
        case .moment: L10n.Composer.postPlaceholder
        case .question: L10n.PostKind.questionPlaceholder
        case .announcement: L10n.PostKind.announcementPlaceholder
        case .notes: L10n.PostKind.notesPlaceholder
        default: L10n.PostKind.genericPlaceholder(title)
        }
    }

    /// Filtre seçiliyken akış boşsa.
    var emptyTitle: String {
        switch self {
        case .moment: L10n.Feed.emptyTitle
        case .question: L10n.PostKind.emptyQuestion
        case .announcement: L10n.PostKind.emptyAnnouncement
        case .notes: L10n.PostKind.emptyNotes
        default: L10n.PostKind.emptyGeneric(title)
        }
    }

    /// Boş durumdaki düğme.
    var emptyAction: String {
        switch self {
        case .moment: L10n.Feed.shareSomething
        case .question: L10n.PostKind.askFirst
        case .announcement: L10n.PostKind.announceFirst
        case .notes: L10n.PostKind.shareNotesFirst
        default: L10n.PostKind.postFirst
        }
    }
}

/// Akış sırası. Reddit modeli: varsayılan Popüler, kronolojik için Yeni.
enum FeedSort: String, CaseIterable, Identifiable {
    case popular, newest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: L10n.Board.popular
        case .newest: L10n.Board.newest
        }
    }

    var systemImage: String {
        switch self {
        case .popular: "flame"
        case .newest: "clock"
        }
    }
}

extension SocialPost {
    /// Benim oyum: +1, -1, 0.
    var myVote: Int { liked ? 1 : (downvoted ? -1 : 0) }

    var isPinned: Bool { pinnedAt != nil }
    /// Sabit sırası; eski kayıtlarda slot yoksa 1.
    var pinSlot: Int { pinnedSlot ?? 1 }

    /// "Popüler" sırası — Common puanı.
    ///
    /// Üç kural: oy alan yükselir, hiçbir şey tepeyi işgal edemez, aynı gönderi
    /// aynı kişiye tekrar tekrar gösterilmez.
    ///
    ///   organik = (net oy + 2 × cevap) / (saat + 2)^1.3
    ///   kurucu  = (eklenen oy / 5) / (1 + gün)      ← her gün üçte bir söner
    ///   puan    = (organik + kurucu) × 0.5^(daha önce kaç kez gördü)
    ///
    /// Yaş: 2 saatte /6, 12 saatte /31, 1 günde /69, 3 günde /256 — 2 saatlik
    /// 34 oylu gönderi ≈ 6 puan; 1 günlük gönderinin onu geçmesi ~400 oy ister.
    /// Kurucu oyu: 100 eklenen oy ilk gün 20 puan (tepeyi alır), ertesi gün 10,
    /// üçüncü gün 7 — kendiliğinden iner, silmek gerekmez.
    /// Görülme: kullanıcı gönderiyi bir oturumda gördüyse puan yarıya iner;
    /// iki oturumda gördüyse görülmemişlerin altına (akış). Kişiye özel, cihazda.
    func popularityScore(seenCount: Int) -> Double {
        let organikOy = Double(likeCount - boost)
        let puan = organikOy + 2 * Double(comments.count)
        let saat = max(0, -createdAt.timeIntervalSinceNow / 3600)
        let organik = puan / pow(saat + 2, 1.3)
        let kurucu = (Double(boost) / 5) / (1 + saat / 24)
        let gorulme = pow(0.5, Double(min(seenCount, 6)))
        return (organik + kurucu) * gorulme
    }

    /// Cevaplar oya göre, eşitlikte eskiden yeniye.
    var rankedComments: [SocialComment] {
        comments.sorted {
            if $0.voteCount != $1.voteCount { return $0.voteCount > $1.voteCount }
            return $0.createdAt < $1.createdAt
        }
    }

    var topComment: SocialComment? { rankedComments.first }

    /// Kartta ve yorum ekranında "cevap" mı "yorum" mu — soruya cevap verilir.
    var repliesAreAnswers: Bool { kind == .question }
}

extension SocialComment {
    var myVote: Int { voted ? 1 : (downvoted ? -1 : 0) }
}
