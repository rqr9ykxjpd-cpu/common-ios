import Foundation

/// Notu olan bir bölüm (20261017020000). Ad, o bölümde en çok kullanılan
/// yazılış; büyük/küçük harf farkı aynı bölüm sayılıyor.
struct NoteDepartment: Identifiable, Hashable, Sendable {
    var id: String { name.lowercased(with: L10n.appLocale) }
    let name: String
    let noteCount: Int
    let lastAt: Date?
}

/// Ders notları: "Kim nerede"de Kulüpler'in altında, bölüme göre. Not, türü
/// `.notes` olan sıradan bir gönderi; yalnızca fotoğraf, gönderi tavanına sayılmaz.
protocol NotesManaging: Sendable {
    func fetchNoteDepartments() async throws -> [NoteDepartment]
    /// Bölümün notları, yeniden eskiye (gönderiler ayrıca getirilir).
    func fetchDepartmentNoteIDs(_ department: String) async throws -> [UUID]
    func createNote(caption: String, department: String, images: [Data]) async throws -> BackendPost
}
