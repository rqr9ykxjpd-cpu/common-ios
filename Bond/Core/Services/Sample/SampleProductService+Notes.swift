#if DEBUG
import Foundation

/// Örnek modda notlar: türü `.notes` olan örnek gönderiler, bölümü yazarın
/// bölümü; yeni not bu açılış boyunca kalır.
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

    func createNote(caption: String, department: String, images: [Data]) async throws -> BackendPost {
        var post = SampleData.newPost(caption: caption, placeName: nil, imageData: images.first, kind: .notes)
        if images.count > 1 { post.galleryData = Array(images.prefix(CampusLimits.maxPostPhotos)) }
        await store.insert(post)
        await SampleNoteStore.shared.set(department.trimmingCharacters(in: .whitespaces), for: post.id)
        return post
    }

    private func notePairs() async -> [(post: BackendPost, department: String)] {
        let yazilan = await SampleNoteStore.shared.all()
        return await store.allPosts()
            .filter { $0.kind == .notes }
            .compactMap { post in
                let bolum = yazilan[post.id] ?? post.authorDepartment
                return bolum.isEmpty ? nil : (post, bolum)
            }
    }
}

private actor SampleNoteStore {
    static let shared = SampleNoteStore()
    private var departments: [UUID: String] = [:]
    func set(_ department: String, for postID: UUID) { departments[postID] = department }
    func all() -> [UUID: String] { departments }
}
#endif
