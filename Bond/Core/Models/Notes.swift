import Foundation

/// Notlar girişi 1.1.7'de açıldı (18 Ekim). 1.1.6'da gizliydi; bayrak,
/// notların akıştan ayrılmasını girişle aynı anda açmak için duruyor.
enum NotesRollout {
    static let isEnabled = true
}

extension SocialPost {
    /// Notlar yalnızca Notlar'da (kurucunun kararı, 17 Ekim): akışta ve
    /// profildeki gönderi listesinde görünmez. Notlar girişi gizliyken eskisi
    /// gibi her yerde görünür, hiçbir yerde kaybolmasın.
    var showsOutsideNotes: Bool { !(NotesRollout.isEnabled && kind == .notes) }
}

enum NoteLimits {
    /// Fotoğraf ya da taranmış sayfa (sunucuda notlar için 20).
    static let maxPages = 20
    /// PDF (sunucuda `note-files` alanının sınırı).
    static let maxPDFBytes = 25 * 1024 * 1024
}

/// Notu olan bir bölüm (20261017020000). Ad, o bölümde en çok kullanılan
/// yazılış; büyük/küçük harf farkı aynı bölüm sayılıyor.
struct NoteDepartment: Identifiable, Hashable, Sendable {
    var id: String { name.lowercased(with: L10n.appLocale) }
    let name: String
    let noteCount: Int
    let lastAt: Date?
}

/// Notun gönderide olmayan kısmı (20261018010000): ders, sayfa sayısı, PDF.
struct NoteExtra: Equatable, Sendable {
    let postID: UUID
    var course: String
    var pageCount: Int
    /// PDF'li notta dosyanın (imzalı) adresi; fotoğraflı notta nil.
    var documentURL: URL?
    var isPDF: Bool { documentURL != nil }
}

/// Paylaşılacak not: ya sayfalar (fotoğraf/tarama) ya PDF.
struct NoteUpload: Sendable {
    var title: String
    var course: String
    var department: String
    /// JPEG sayfalar (en fazla `NoteLimits.maxPages`).
    var pages: [Data] = []
    var pdf: Data?
    /// PDF'in ilk sayfasının resmi: akışta ve eski sürümlerde görünür.
    var pdfThumbnail: Data?
    var pageCount: Int
}

/// Ders notları: Kim nerede'de Kulüpler'in altında, bölüme göre. Not, türü
/// `.notes` olan bir gönderi; gönderi tavanına sayılmaz.
protocol NotesManaging: Sendable {
    func fetchNoteDepartments() async throws -> [NoteDepartment]
    /// Bölümün notları, yeniden eskiye (gönderiler ayrıca getirilir).
    func fetchDepartmentNoteIDs(_ department: String) async throws -> [UUID]
    func searchNoteIDs(_ query: String) async throws -> [UUID]
    func fetchNoteExtras(_ postIDs: [UUID]) async throws -> [NoteExtra]
    func createNote(_ note: NoteUpload) async throws -> BackendPost
}
