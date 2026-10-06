import Foundation

/// Gönderide yorumun yanındaki düğme. Yalnızca resmi Common hesabı kendi
/// gönderisine ekler (sunucu: `set_post_cta`). Ham değer sunucudaki
/// `posts.cta`; tanınmayan değer düğmesiz çizilir.
enum PostAction: String, CaseIterable, Identifiable, Sendable {
    case invite
    case appIcon = "app_icon"
    case plus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invite: L10n.PostAction.invite
        case .appIcon: L10n.PostAction.appIcon
        case .plus: L10n.PostAction.plus
        }
    }

    var systemImage: String {
        switch self {
        case .invite: "person.badge.plus"
        case .appIcon: "app.badge"
        case .plus: "crown"
        }
    }
}
