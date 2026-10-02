import Foundation

/// "Tanıyor olabileceğin kişiler" satırındaki bir öneri.
///
/// Her önerinin somut bir sebebi var ve sebep yuvarlağın altında yazıyor;
/// sebebi olmayan kimse önerilmiyor (sunucudaki `get_people_you_may_know`).
struct PersonSuggestion: Identifiable, Hashable, Sendable {
    let profile: StudentProfile
    let reason: Reason

    var id: UUID { profile.id }

    enum Reason: Hashable, Sendable {
        /// Sohbetini temizlediğin bağlantın: kartı açıp yeniden yazabilesin.
        case connection
        /// Ortak bağlantı sayısı.
        case mutual(Int)
        /// Ortak kulübün adı.
        case club(String)
        /// Aynı bölüm ve sınıf.
        case classmate(department: String)
        /// Aynı bölüm, başka sınıf.
        case department(String)
        /// Ortak ilgi alanı sayısı (en az iki).
        case interests(Int)

        /// Sunucudaki `reason` / `reason_detail` / `reason_count` üçlüsünden.
        /// Tanınmayan bir sebep gelirse öneri gösterilmiyor.
        init?(server reason: String, detail: String?, count: Int) {
            switch reason {
            case "connection": self = .connection
            case "mutual" where count > 0: self = .mutual(count)
            case "club": guard let detail, !detail.isEmpty else { return nil }; self = .club(detail)
            case "classmate": self = .classmate(department: detail ?? "")
            case "department": self = .department(detail ?? "")
            case "interests" where count >= 2: self = .interests(count)
            default: return nil
            }
        }

        /// Yuvarlağın altındaki kısa satır.
        var label: String {
            switch self {
            case .connection: L10n.Suggestions.connection
            case .mutual(let count): L10n.Suggestions.mutual(count)
            case .club(let name): name
            case .classmate: L10n.Suggestions.classmate
            case .department(let department): DepartmentCatalog.educationParts(department).first ?? department
            case .interests(let count): L10n.Suggestions.interests(count)
            }
        }
    }
}
