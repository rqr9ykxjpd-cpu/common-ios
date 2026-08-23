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

    /// Bölüm + dil track gibi bitişik parçaları ayırır ("İktisat İngilizce" → ["İktisat", "İngilizce"]).
    /// Katalogdaki çok kelimeli bölüm adlarını parçalamaz.
    static func educationParts(_ id: String) -> [String] {
        let shown = display(id).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shown.isEmpty else { return [] }

        let separators = CharacterSet(charactersIn: "·/,|")
        if shown.rangeOfCharacter(from: separators) != nil {
            return shown
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let languageTracks = ["İngilizce", "English", "Almanca", "Fransızca", "İspanyolca"]
        for lang in languageTracks {
            let suffix = " \(lang)"
            if shown.hasSuffix(suffix) {
                let major = String(shown.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !major.isEmpty { return [major, lang] }
            }
        }

        // "İktisat (İngilizce)" biçimi
        if let open = shown.lastIndex(of: "("), let close = shown.lastIndex(of: ")"),
           open < close, close == shown.index(before: shown.endIndex) {
            let major = shown[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
            let track = shown[shown.index(after: open)..<close].trimmingCharacters(in: .whitespacesAndNewlines)
            if !major.isEmpty, !track.isEmpty { return [String(major), String(track)] }
        }

        return [shown]
    }
}

enum UniversityCatalog {
    /// Kısa kod ("YÜ") saklanır; ekranda istenirse açık ad gösterilir.
    static func display(_ id: String, expanded: Bool = false) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard expanded else { return trimmed }
        switch trimmed.uppercased() {
        case "YÜ", "YU": return L10n.Common.yalovaUniversity
        default: return trimmed
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
