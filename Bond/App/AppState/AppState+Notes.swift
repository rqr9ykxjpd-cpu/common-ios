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

    /// Bölümün notları, yeniden eskiye.
    func departmentNotes(_ department: String) async throws -> [SocialPost] {
        guard let masa = service as? any NotesManaging else { return [] }
        return try await notes(ids: masa.fetchDepartmentNoteIDs(department))
    }

    /// Ders, konu ya da bölümde geçen notlar (en az 2 harf).
    func searchNotes(_ query: String) async throws -> [SocialPost] {
        let aranan = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard aranan.count >= 2, let masa = service as? any NotesManaging else { return [] }
        return try await notes(ids: masa.searchNoteIDs(aranan))
    }

    /// Akıştaki notların dersi ve sayfaları ("Notu aç"). Sunucu eskiyse ya da
    /// ağ yoksa not sıradan gönderi gibi kalır.
    func loadNoteExtras(for posts: [SocialPost]) async {
        guard let masa = service as? any NotesManaging else { return }
        let ids = posts.filter { $0.kind == .notes }.map(\.id)
        guard !ids.isEmpty, let gelen = try? await masa.fetchNoteExtras(ids) else { return }
        for ek in gelen { noteExtras[ek.postID] = ek }
    }

    /// Akış gönderilerinin etkinlik kartı ve not bilgisi, aynı anda.
    func loadPostExtras(for posts: [SocialPost]) async {
        async let olaylar: Void = loadPostEvents(for: posts)
        async let notlar: Void = loadNoteExtras(for: posts)
        _ = await (olaylar, notlar)
    }

    /// PDF adresi bir saat geçerli; okuyucu açılırken süresi geçmişse yenilenir.
    func refreshNoteExtra(_ postID: UUID) async -> NoteExtra? {
        guard let masa = service as? any NotesManaging,
              let ek = try? await masa.fetchNoteExtras([postID]).first else { return noteExtras[postID] }
        noteExtras[postID] = ek
        return ek
    }

    /// Not paylaş: sayfalar ya da PDF; gönderi tavanına sayılmaz.
    @discardableResult
    func publishNote(_ note: NoteUpload) async -> Bool {
        guard requireStudent(), let masa = service as? any NotesManaging,
              !note.pages.isEmpty || note.pdf != nil else { return false }
        do {
            let post = try await masa.createNote(note)
            var social = socialPost(from: post)
            if social.isMine, social.author.badge == .none, myBadge != .none {
                social = socialPost(from: post, badgeOverride: myBadge)
            }
            if let ek = try? await masa.fetchNoteExtras([post.id]).first { noteExtras[ek.postID] = ek }
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

    /// Okuyucunun dosyası: PDF'li notta PDF, fotoğraflı notta sayfalardan
    /// yapılan PDF. Diskte durur (çıkışta medya önbelleğiyle silinir); ikinci
    /// açılış anında ve ağsız.
    func noteDocument(for post: SocialPost) async -> URL? {
        let klasor = FileManager.default.temporaryDirectory
            .appendingPathComponent("bond-media/notes/\(post.id.uuidString.lowercased())", isDirectory: true)
        if let olan = try? FileManager.default.contentsOfDirectory(at: klasor, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "pdf" }) {
            return olan
        }
        var ek = noteExtras[post.id]
        var veri: Data?
        if ek?.isPDF == true {
            // İmzalı adres bir saat geçerli: açarken tazesi alınır.
            ek = await refreshNoteExtra(post.id) ?? ek
            if let adres = ek?.documentURL { veri = await Self.downloadPDF(adres) }
        } else {
            veri = await NotePDF.make(pages: notePageData(post))
        }
        guard let veri else { return nil }
        let yer = klasor.appendingPathComponent(NotePDF.fileName(course: ek?.course ?? "", title: post.caption))
        do {
            try FileManager.default.createDirectory(at: klasor, withIntermediateDirectories: true)
            try veri.write(to: yer, options: .atomic)
        } catch {
            return nil
        }
        return yer
    }

    /// Fotoğraflı notun sayfaları, sırasıyla.
    private func notePageData(_ post: SocialPost) async -> [Data] {
        if post.galleryData.count > 1 { return post.galleryData }
        var adresler = post.galleryURLs
        if adresler.isEmpty, let ilk = post.imageURL { adresler = [ilk] }
        if adresler.isEmpty { return post.localImageData.map { [$0] } ?? [] }
        let service = service
        return await withTaskGroup(of: (Int, Data?).self) { group in
            for (sira, adres) in adresler.enumerated() {
                group.addTask { (sira, await Self.fetchNoteMedia(adres, service: service)) }
            }
            var gelen: [(Int, Data?)] = []
            for await parca in group { gelen.append(parca) }
            return gelen.sorted { $0.0 < $1.0 }.compactMap(\.1)
        }
    }

    nonisolated private static func fetchNoteMedia(_ url: URL, service: any ProductService) async -> Data? {
        if let supabase = service as? SupabaseProductService { return await supabase.loadMediaData(url) }
        if url.isFileURL { return try? Data(contentsOf: url) }
        return try? await URLSession.shared.data(from: url).0
    }

    nonisolated private static func downloadPDF(_ url: URL) async -> Data? {
        if url.isFileURL { return try? Data(contentsOf: url) }
        guard let (veri, yanit) = try? await URLSession.shared.data(from: url),
              let http = yanit as? HTTPURLResponse, (200...299).contains(http.statusCode),
              veri.starts(with: Data("%PDF".utf8)) else { return nil }
        return veri
    }

    /// Gönderiler sırasıyla getirilir; okuyucu ve gönderi sayfası `posts`
    /// içinden okuduğu için listeye de eklenir.
    private func notes(ids: [UUID]) async throws -> [SocialPost] {
        guard !ids.isEmpty else { return [] }
        let gelen = try await service.fetchPosts(ids: ids)
        let sira = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let notlar = gelen.map { socialPost(from: $0) }
            .filter { !deletedPostIDs.contains($0.id) }
            .sorted { (sira[$0.id] ?? .max) < (sira[$1.id] ?? .max) }
        await loadNoteExtras(for: notlar)
        let mevcut = Set(posts.map(\.id))
        posts.append(contentsOf: notlar.filter { !mevcut.contains($0.id) })
        return notlar
    }
}
