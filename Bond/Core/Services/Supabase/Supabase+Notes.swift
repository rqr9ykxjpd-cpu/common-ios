import Foundation
import Supabase

extension SupabaseProductService: NotesManaging {
    func fetchNoteDepartments() async throws -> [NoteDepartment] {
        guard currentUserID != nil else { return [] }
        let rows: [NoteDepartmentRow] = try await client.rpc("get_note_departments").execute().value
        return rows.map { NoteDepartment(name: $0.department, noteCount: $0.noteCount, lastAt: $0.lastAt) }
    }

    func fetchDepartmentNoteIDs(_ department: String) async throws -> [UUID] {
        guard currentUserID != nil else { return [] }
        return try await client
            .rpc("get_department_note_ids", params: DepartmentParams(department: department))
            .execute().value
    }

    func searchNoteIDs(_ query: String) async throws -> [UUID] {
        guard currentUserID != nil else { return [] }
        return try await client.rpc("search_note_ids", params: NoteSearchParams(q: query)).execute().value
    }

    func fetchNoteExtras(_ postIDs: [UUID]) async throws -> [NoteExtra] {
        guard currentUserID != nil, !postIDs.isEmpty else { return [] }
        let rows: [NoteExtraRow] = try await client
            .from("posts")
            .select("id,course,document_path,page_count,media_paths")
            .`in`("id", values: postIDs)
            .execute().value
        let dosyalar = await signedURLs(bucket: "note-files", paths: rows.compactMap(\.documentPath))
        return rows.map { row in
            NoteExtra(postID: row.id, course: row.course ?? "",
                      pageCount: row.pageCount ?? max(1, row.mediaPaths?.count ?? 1),
                      documentURL: row.documentPath.flatMap { dosyalar[$0] })
        }
    }

    /// Önce dosyalar yüklenir; not satırı yazılamazsa yüklenenler silinir.
    func createNote(_ note: NoteUpload) async throws -> BackendPost {
        guard let userID = currentUserID else { throw BackendServiceError.missingSession }
        try ContentSafety.validate(note.title)
        try ContentSafety.validate(note.course)
        try ContentSafety.validate(note.department)
        let klasor = userID.uuidString.lowercased()
        var resimler: [(path: String, data: Data)] = []
        var belge: String?
        if let pdf = note.pdf {
            belge = "\(klasor)/\(UUID().uuidString.lowercased()).pdf"
            if let kapak = note.pdfThumbnail {
                resimler = [("\(klasor)/\(UUID().uuidString.lowercased()).jpg", kapak)]
            }
            try await client.storage.from("note-files")
                .upload(belge!, data: pdf, options: FileOptions(contentType: "application/pdf"))
        } else {
            resimler = note.pages.prefix(NoteLimits.maxPages).map {
                ("\(klasor)/\(UUID().uuidString.lowercased()).jpg", $0)
            }
        }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for resim in resimler {
                    group.addTask {
                        try await self.client.storage.from("post-media")
                            .upload(resim.path, data: resim.data, options: FileOptions(contentType: "image/jpeg"))
                    }
                }
                try await group.waitForAll()
            }
            let yollar = resimler.map(\.path)
            let satir = NoteInsert(
                authorID: userID,
                caption: note.title.trimmingCharacters(in: .whitespacesAndNewlines),
                department: note.department.trimmingCharacters(in: .whitespacesAndNewlines),
                course: note.course.trimmingCharacters(in: .whitespacesAndNewlines),
                mediaPath: yollar.first,
                mediaPaths: yollar.count > 1 ? yollar : nil,
                documentPath: belge,
                pageCount: note.pageCount
            )
            let eklenen: InsertedID = try await client.from("posts").insert(satir).select("id").single().execute().value
            guard let post = try await fetchPosts(ids: [eklenen.id]).first else { throw BackendServiceError.missingSession }
            return post
        } catch {
            if !resimler.isEmpty { _ = try? await client.storage.from("post-media").remove(paths: resimler.map(\.path)) }
            if let belge { _ = try? await client.storage.from("note-files").remove(paths: [belge]) }
            throw error
        }
    }
}

private struct NoteDepartmentRow: Decodable {
    let department: String
    let noteCount: Int
    let lastAt: Date?

    enum CodingKeys: String, CodingKey {
        case department
        case noteCount = "note_count"
        case lastAt = "last_at"
    }
}

private struct NoteExtraRow: Decodable {
    let id: UUID
    let course: String?
    let documentPath: String?
    let pageCount: Int?
    let mediaPaths: [String]?

    enum CodingKeys: String, CodingKey {
        case id, course
        case documentPath = "document_path"
        case pageCount = "page_count"
        case mediaPaths = "media_paths"
    }
}

private struct NoteInsert: Encodable {
    let authorID: UUID
    let caption: String
    let kind = PostKind.notes
    let department: String
    let course: String
    let mediaPath: String?
    let mediaPaths: [String]?
    let documentPath: String?
    let pageCount: Int

    enum CodingKeys: String, CodingKey {
        case caption, kind, department, course
        case authorID = "author_id"
        case mediaPath = "media_path"
        case mediaPaths = "media_paths"
        case documentPath = "document_path"
        case pageCount = "page_count"
    }
}

private struct InsertedID: Decodable { let id: UUID }

private struct DepartmentParams: Encodable { let department: String }
private struct NoteSearchParams: Encodable { let q: String }
