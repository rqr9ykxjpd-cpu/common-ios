#if DEBUG
import Foundation

/// Örnek modda notlar: türü `.notes` olan örnek gönderiler. Ders, bölüm ve
/// PDF `SampleData.sampleNotes`ten; yeni not bu açılış boyunca kalır.
extension SampleProductService: NotesManaging {
    func fetchNoteDepartments() async throws -> [NoteDepartment] {
        let notlar = await notePairs()
        let gruplar = Dictionary(grouping: notlar) { $0.department.lowercased(with: L10n.appLocale) }
        return gruplar.values.compactMap { grup in
            guard let ilk = grup.first else { return nil }
            return NoteDepartment(name: ilk.department, noteCount: grup.count, lastAt: grup.map(\.post.createdAt).max())
        }
        .sorted { ($0.lastAt ?? .distantPast) > ($1.lastAt ?? .distantPast) }
    }

    func fetchDepartmentNoteIDs(_ department: String) async throws -> [UUID] {
        let anahtar = department.trimmingCharacters(in: .whitespaces).lowercased(with: L10n.appLocale)
        return await notePairs()
            .filter { $0.department.lowercased(with: L10n.appLocale) == anahtar }
            .sorted { $0.post.createdAt > $1.post.createdAt }
            .map(\.post.id)
    }

    func searchNoteIDs(_ query: String) async throws -> [UUID] {
        let aranan = query.trimmingCharacters(in: .whitespaces).lowercased(with: L10n.appLocale)
        guard aranan.count >= 2 else { return [] }
        let ekler = await SampleNoteStore.shared.extras()
        return await notePairs()
            .filter { cift in
                [cift.post.caption, ekler[cift.post.id]?.course ?? "", cift.department]
                    .contains { $0.lowercased(with: L10n.appLocale).contains(aranan) }
            }
            .sorted { $0.post.createdAt > $1.post.createdAt }
            .map(\.post.id)
    }

    func fetchNoteExtras(_ postIDs: [UUID]) async throws -> [NoteExtra] {
        let ekler = await SampleNoteStore.shared.extras()
        let istenen = Set(postIDs)
        return await store.allPosts()
            .filter { istenen.contains($0.id) && $0.kind == .notes }
            .map { post in
                ekler[post.id] ?? NoteExtra(postID: post.id, course: "",
                                           pageCount: max(1, post.galleryData.count), documentURL: nil)
            }
    }

    func createNote(_ note: NoteUpload) async throws -> BackendPost {
        let sayfalar = Array(note.pages.prefix(NoteLimits.maxPages))
        var post = SampleData.newPost(caption: note.title, placeName: nil,
                                      imageData: note.pdfThumbnail ?? sayfalar.first, kind: .notes)
        if note.pdf == nil, sayfalar.count > 1 { post.galleryData = sayfalar }
        var dosya: URL?
        if let pdf = note.pdf {
            let yer = FileManager.default.temporaryDirectory.appendingPathComponent("sample-note-\(post.id).pdf")
            try pdf.write(to: yer)
            dosya = yer
        }
        await store.insert(post)
        await SampleNoteStore.shared.set(
            NoteExtra(postID: post.id, course: note.course, pageCount: note.pageCount, documentURL: dosya),
            department: note.department.trimmingCharacters(in: .whitespaces)
        )
        return post
    }

    private func notePairs() async -> [(post: BackendPost, department: String)] {
        let bolumler = await SampleNoteStore.shared.departments()
        return await store.allPosts()
            .filter { $0.kind == .notes }
            .compactMap { post in
                let bolum = bolumler[post.id] ?? post.authorDepartment
                return bolum.isEmpty ? nil : (post, bolum)
            }
    }
}

private actor SampleNoteStore {
    static let shared = SampleNoteStore()
    private var departmentsByPost: [UUID: String] = [:]
    private var extrasByPost: [UUID: NoteExtra] = [:]

    init() {
        for not in SampleData.sampleNotes {
            if let bolum = not.department { departmentsByPost[not.id] = bolum }
            var dosya: URL?
            if not.isPDF {
                let yer = FileManager.default.temporaryDirectory.appendingPathComponent("sample-note-\(not.id).pdf")
                if (try? SampleData.samplePDF(not).write(to: yer)) != nil { dosya = yer }
            }
            extrasByPost[not.id] = NoteExtra(postID: not.id, course: not.course,
                                             pageCount: not.pages.count, documentURL: dosya)
        }
    }

    func set(_ extra: NoteExtra, department: String) {
        extrasByPost[extra.postID] = extra
        departmentsByPost[extra.postID] = department
    }
    func departments() -> [UUID: String] { departmentsByPost }
    func extras() -> [UUID: NoteExtra] { extrasByPost }
}
#endif
