import SwiftUI

// MARK: - AppState+Notes
extension AppState {
    /// Notu olan bölümler. Kendi bölümün listede yoksa da en üstte durur:
    /// ilk notu sen paylaşabilesin.
    func fetchNoteDepartments() async throws -> [NoteDepartment] {
        guard let masa = service as? any NotesManaging else { return [] }
        var liste = try await masa.fetchNoteDepartments()
        let benim = currentUserProfile.department.trimmingCharacters(in: .whitespacesAndNewlines)
        if !benim.isEmpty {
            let anahtar = benim.lowercased(with: L10n.appLocale)
            if let i = liste.firstIndex(where: { $0.id == anahtar }) {
                liste.insert(liste.remove(at: i), at: 0)
            } else {
                liste.insert(NoteDepartment(name: benim, noteCount: 0, lastAt: nil), at: 0)
            }
        }
        return liste
    }

    /// Bölümün notları, yeniden eskiye; gönderi sayfası açılabilsin diye
    /// akıştaki listeye de eklenir.
    func departmentNotes(_ department: String) async throws -> [SocialPost] {
        guard let masa = service as? any NotesManaging else { return [] }
        let ids = try await masa.fetchDepartmentNoteIDs(department)
        guard !ids.isEmpty else { return [] }
        let gelen = try await service.fetchPosts(ids: ids)
        let sira = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let notlar = gelen.map { socialPost(from: $0) }
            .filter { !deletedPostIDs.contains($0.id) }
            .sorted { (sira[$0.id] ?? .max) < (sira[$1.id] ?? .max) }
        let mevcut = Set(posts.map(\.id))
        posts.append(contentsOf: notlar.filter { !mevcut.contains($0.id) })
        return notlar
    }

    /// Not paylaş: yalnızca fotoğraf; gönderi tavanına sayılmaz.
    @discardableResult
    func publishNote(caption: String, department: String, images: [Data]) async -> Bool {
        guard requireStudent(), let masa = service as? any NotesManaging, !images.isEmpty else { return false }
        do {
            let post = try await masa.createNote(
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                department: department, images: images
            )
            var social = socialPost(from: post)
            if social.isMine, social.author.badge == .none, myBadge != .none {
                social = socialPost(from: post, badgeOverride: myBadge)
            }
            posts.insert(social, at: 0)
            justPublishedPostIDs.insert(social.id)
            Haptics.success()
            show(L10n.Notes.shared)
            return true
        } catch {
            showError(error, fallback: L10n.Notes.shareFailed)
            return false
        }
    }
}
