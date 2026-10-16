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

    func createNote(caption: String, department: String, images: [Data]) async throws -> BackendPost {
        try await createPost(caption: caption, placeName: nil, images: images, kind: .notes, department: department)
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

private struct DepartmentParams: Encodable {
    let department: String
}
