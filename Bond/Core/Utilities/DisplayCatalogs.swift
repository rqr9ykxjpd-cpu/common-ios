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

    private static let languageTracks = ["İngilizce", "English", "Almanca", "Fransızca", "İspanyolca"]

    static func display(_ id: String) -> String {
        let raw: String = {
            switch id {
            case "Psikoloji": L10n.Department.psychology
            case "Endüstri Mühendisliği": L10n.Department.industrial
            case "İşletme": L10n.Department.business
            case "Bilgisayar Mühendisliği": L10n.Department.cs
            case "Hukuk": L10n.Department.law
            default: id
            }
        }()
        return formatLanguageTrack(raw)
    }

    /// Bölüm satırında gösterilecek parçalar.
    ///
    /// Dil track'i ayrı bir "bölüm" gibi noktalarla ayrılmasın: "İktisat İngilizce"
    /// → tek parça "İktisat (İngilizce)". Gerçek çoklu bölüm ayırıcıları (· / , |) durur.
    static func educationParts(_ id: String) -> [String] {
        let shown = display(id).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shown.isEmpty else { return [] }

        // display() dil track'i zaten paranteze aldıysa tek parça.
        if shown.contains("("), shown.hasSuffix(")") { return [shown] }

        let separators = CharacterSet(charactersIn: "·/,|")
        if shown.rangeOfCharacter(from: separators) != nil {
            let parts = shown
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.count >= 2, let lang = languageTrack(matching: parts.last!) {
                let major = parts.dropLast().joined(separator: " ")
                return ["\(major) (\(lang))"]
            }
            return parts
        }

        return [shown]
    }

    /// "İktisat İngilizce" / "İktisat · İngilizce" → "İktisat (İngilizce)".
    private static func formatLanguageTrack(_ value: String) -> String {
        let shown = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shown.isEmpty else { return shown }

        // Zaten parantezliyse dokunma.
        if let open = shown.lastIndex(of: "("), let close = shown.lastIndex(of: ")"),
           open < close, close == shown.index(before: shown.endIndex) {
            return shown
        }

        let separators = CharacterSet(charactersIn: "·/,|")
        if shown.rangeOfCharacter(from: separators) != nil {
            let parts = shown
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.count >= 2, let lang = languageTrack(matching: parts.last!) {
                let major = parts.dropLast().joined(separator: " ")
                return "\(major) (\(lang))"
            }
            return shown
        }

        for lang in languageTracks {
            let suffix = " \(lang)"
            if shown.hasSuffix(suffix) {
                let major = String(shown.dropLast(suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !major.isEmpty { return "\(major) (\(lang))" }
            }
        }
        return shown
    }

    private static func languageTrack(matching value: String) -> String? {
        languageTracks.first { $0.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
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
