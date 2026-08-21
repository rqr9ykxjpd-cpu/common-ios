import Foundation

/// Saklanan kimlikler Türkçe kalır (eşleşme/filtre bunlara bakıyor). Ekranda dil dosyasından gelir.
enum AcademicYear {
    static let all = ["Hazırlık", "1. sınıf", "2. sınıf", "3. sınıf", "4. sınıf", "Lisansüstü"]

    static func display(_ id: String) -> String {
        switch id {
        case "Hazırlık": L10n.Year.prep
        case "1. sınıf": L10n.Year.first
        case "2. sınıf": L10n.Year.second
        case "3. sınıf": L10n.Year.third
        case "4. sınıf": L10n.Year.fourth
        case "Lisansüstü": L10n.Year.grad
        default: id
        }
    }
}

enum DepartmentCatalog {
    static let all = ["Psikoloji", "Endüstri Mühendisliği", "İşletme", "Bilgisayar Mühendisliği", "Hukuk"]

    static func display(_ id: String) -> String {
        switch id {
        case "Psikoloji": L10n.Department.psychology
        case "Endüstri Mühendisliği": L10n.Department.industrial
        case "İşletme": L10n.Department.business
        case "Bilgisayar Mühendisliği": L10n.Department.cs
        case "Hukuk": L10n.Department.law
        default: id
        }
    }
}

enum CompatibilityCopy {
    static func localize(_ reason: String) -> String {
        if reason == "Aynı sınıf düzeyi" { return L10n.Discovery.sameYear }
        if let count = commonInterestCount(reason) {
            return L10n.Discovery.commonInterests(count)
        }
        return reason
    }

    private static func commonInterestCount(_ reason: String) -> Int? {
        let suffix = " ortak ilgi alanı"
        guard reason.hasSuffix(suffix) else { return nil }
        return Int(reason.dropLast(suffix.count))
    }
}

enum NotificationCopy {
    static func title(kind: AppNotificationKind, actorName: String, serverTitle: String) -> String {
        switch kind {
        case .match:
            return L10n.Notification.matchTitle
        case .message:
            if serverTitle.contains("yazmak istiyor") {
                return L10n.Notification.messageRequestTitle(actorName)
            }
            return L10n.Notification.messageTitle(actorName)
        case .comment:
            return L10n.Notification.commentTitle(actorName)
        case .like:
            if serverTitle.contains("story") {
                return L10n.Notification.storyLikeTitle(actorName)
            }
            return L10n.Notification.postLikeTitle(actorName)
        case .meetingRequest:
            if serverTitle.contains("kabul") {
                return L10n.Notification.meetingAcceptedTitle(actorName)
            }
            return L10n.Notification.meetingTitle(actorName)
        case .club:
            return L10n.Notification.clubTitle
        }
    }

    static func body(kind: AppNotificationKind, actorName: String, serverTitle: String, serverBody: String) -> String {
        switch kind {
        case .match:
            return L10n.Notification.matchBody(actorName)
        case .message, .comment:
            return serverBody
        case .like:
            return serverBody
        case .meetingRequest:
            let place = serverBody
                .replacingOccurrences(of: " için gönderilen isteği yanıtla.", with: "")
                .replacingOccurrences(of: " için buluşmanız onaylandı.", with: "")
            if serverTitle.contains("kabul") {
                return L10n.Notification.meetingAcceptedBody(place)
            }
            return L10n.Notification.meetingBody(place)
        case .club:
            return serverBody
        }
    }
}
