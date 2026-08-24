import Foundation
import Supabase

extension SupabaseProductService {
    func removeAllFiles(ownedBy userID: UUID) async {
        let folder = userID.uuidString.lowercased()
        for bucket in ["profile-photos", "post-media", "story-media"] {
            guard let files = try? await client.storage.from(bucket).list(path: folder) else { continue }
            let paths = files.map { "\(folder)/\($0.name)" }
            guard !paths.isEmpty else { continue }
            _ = try? await client.storage.from(bucket).remove(paths: paths)
        }
    }

    func badges(for ids: [UUID]) async -> [UUID: ProfileBadge] {
        guard !ids.isEmpty else { return [:] }
        let rows: [ProfileBadgeRow]? = try? await client
            .from("profiles")
            .select("id,badge")
            .`in`("id", values: Array(Set(ids)))
            .execute()
            .value
        guard let rows else { return [:] }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.badge ?? .none) })
    }

    /// Kendi rozetim; aynı sebeple ayrı ve dayanıklı.
    func myBadge() async -> ProfileBadge {
        guard let userID = currentUserID else { return .none }
        return await badges(for: [userID])[userID] ?? .none
    }
    func removeMedia(bucket: String, table: String, rowID: UUID) async {
        let rows: [MediaPathRow]? = try? await client
            .from(table)
            .select("media_path")
            .eq("id", value: rowID)
            .execute()
            .value
        guard let path = rows?.first?.mediaPath else { return }
        _ = try? await client.storage.from(bucket).remove(paths: [path])
    }

    /// Story satırındaki asıl dosya + video kapağı. Kapak silinmezse bucket'ta
    /// sahipsiz JPEG kalır; `can_read_media` de onu artık bağlayamaz.
    func removeStoryFiles(_ storyID: UUID) async {
        let rows: [ExpiredStoryRow]? = try? await client
            .from("stories")
            .select("id,media_path,poster_path")
            .eq("id", value: storyID)
            .execute()
            .value
        let paths = [rows?.first?.mediaPath, rows?.first?.posterPath].compactMap { $0 }.filter { !$0.isEmpty }
        guard !paths.isEmpty else { return }
        _ = try? await client.storage.from("story-media").remove(paths: paths)
    }

    /// Profil fotoğrafının CDN adresi. SDK `appendingPathComponent` ile `/` işaretini
    /// `%2F` yapabiliyor; burada yol `URLComponents` ile kuruluyor.
    func publicProfilePhotoURL(_ path: String) -> URL? {
        storageHTTPURL(kind: "public", bucket: "profile-photos", path: path).map(Self.usableSignedURL)
    }

    /// Görseller: oturumlu GET / public GET / SDK indirme → `file://`.
    /// Video: imzalı HTTPS. Profil fotoğrafında yalnızca public URL üretmek,
    /// bucket kapalıyken Tanış kartını boş bırakıyordu.
    func signedURLs(bucket: String, paths: [String]) async -> [String: URL] {
        let uniquePaths = Array(Set(paths.filter { !$0.isEmpty }))
        guard !uniquePaths.isEmpty else { return [:] }
        var map: [String: URL] = [:]
        await withTaskGroup(of: (String, URL?).self) { group in
            for path in uniquePaths {
                group.addTask { await self.resolveOneMediaURL(bucket: bucket, path: path) }
            }
            for await (path, url) in group {
                if let url {
                    map[path] = url
                    map[Self.normalizedMediaPath(path)] = url
                }
            }
        }
        var keyed: [String: URL] = [:]
        for path in uniquePaths {
            if let url = map[path] ?? map[Self.normalizedMediaPath(path)] {
                keyed[path] = url
            }
        }
        #if DEBUG
        let missing = uniquePaths.filter { keyed[$0] == nil }
        print("Bond media: \(bucket) \(keyed.count)/\(uniquePaths.count) URL\(missing.isEmpty ? "" : ", eksik \(Array(missing.prefix(3)))")")
        #endif
        return keyed
    }

    private func resolveOneMediaURL(bucket: String, path: String) async -> (String, URL?) {
        if !Self.isProbablyVideo(path) {
            if let data = await downloadImageData(bucket: bucket, path: path),
               let fileURL = cacheMediaFile(data: data, path: path) {
                return (path, fileURL)
            }
        }
        if bucket == "profile-photos", let url = publicProfilePhotoURL(path) {
            return (path, url)
        }
        if let url = try? await client.storage.from(bucket).createSignedURL(path: path, expiresIn: 3_600) {
            return (path, Self.usableSignedURL(url))
        }
        return (path, nil)
    }

    private func downloadImageData(bucket: String, path: String) async -> Data? {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var candidates = [path, trimmed, trimmed.lowercased()]
        for prefix in ["profile-photos/", "post-media/", "story-media/"] where trimmed.lowercased().hasPrefix(prefix) {
            candidates.append(String(trimmed.dropFirst(prefix.count)))
        }
        var seen: Set<String> = []
        for candidate in candidates where seen.insert(candidate).inserted && !candidate.isEmpty {
            if let data = await fetchStorageObject(bucket: bucket, path: candidate) {
                return data
            }
        }
        return nil
    }

    /// SDK indirmesi yolu `%2F` kodlarsa 404 olur. Public ve oturumlu GET
    /// burada `URLComponents` ile kuruluyor.
    private func fetchStorageObject(bucket: String, path: String) async -> Data? {
        if let url = storageHTTPURL(kind: "public", bucket: bucket, path: path),
           let data = await Self.httpImageData(url), Self.isImageData(data) {
            return data
        }
        if let url = storageHTTPURL(kind: nil, bucket: bucket, path: path),
           let data = await authorizedStorageData(url), Self.isImageData(data) {
            return data
        }
        do {
            let data = try await client.storage.from(bucket).download(path: path)
            if Self.isImageData(data) { return data }
        } catch {
            #if DEBUG
            print("Bond media download \(bucket)/\(path): \(error)")
            #endif
        }
        return nil
    }

    private func storageHTTPURL(kind: String?, bucket: String, path: String) -> URL? {
        guard let root = AppSecrets.supabaseURL else { return nil }
        var components = URLComponents(url: root, resolvingAgainstBaseURL: false)
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let kind {
            components?.path = "/storage/v1/object/\(kind)/\(bucket)/\(trimmed)"
        } else {
            components?.path = "/storage/v1/object/\(bucket)/\(trimmed)"
        }
        components?.query = nil
        return components?.url
    }

    private func authorizedStorageData(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let key = AppSecrets.supabasePublishableKey
        request.setValue(key, forHTTPHeaderField: "apikey")
        let token = client.auth.currentSession?.accessToken ?? key
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await Self.mediaSession.data(for: request),
              let http = response as? HTTPURLResponse else { return nil }
        #if DEBUG
        if !(200...299).contains(http.statusCode) {
            print("Bond media auth GET \(http.statusCode) \(url.path)")
        }
        #endif
        guard (200...299).contains(http.statusCode) else { return nil }
        return data
    }

    /// Önce imzalı GET. Olmazsa oturumlu Storage indirmesi.
    func loadMediaData(_ url: URL) async -> Data? {
        if url.isFileURL {
            return try? Data(contentsOf: url)
        }
        let fetchURL = Self.usableSignedURL(Self.strippingCacheBust(url))
        if let data = await Self.httpImageData(fetchURL) {
            return data
        }
        if let object = Self.storageObject(from: fetchURL),
           let data = await downloadImageData(bucket: object.bucket, path: object.path) {
            return data
        }
        return nil
    }

    private static let mediaSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    private static func strippingCacheBust(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = components.queryItems?.filter { $0.name != "cacheNonce" }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        return components.url ?? url
    }

    /// SDK göreli yolu `storage/v1` ile birleştirirken bazen yolu ikiye katlıyor.
    private static func usableSignedURL(_ url: URL) -> URL {
        var text = url.absoluteString
        while text.contains("/storage/v1/storage/v1/") {
            text = text.replacingOccurrences(of: "/storage/v1/storage/v1/", with: "/storage/v1/")
        }
        return URL(string: text) ?? url
    }

    private static func httpImageData(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await mediaSession.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              isImageData(data) else { return nil }
        return data
    }

    private static func isProbablyVideo(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v")
    }

    private static func isImageData(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let prefix = [UInt8](data.prefix(12))
        if prefix.starts(with: [0xFF, 0xD8, 0xFF]) { return true }
        if prefix.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        if prefix.starts(with: [0x47, 0x49, 0x46]) { return true }
        if prefix.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(prefix[8..<12]) == [0x57, 0x45, 0x42, 0x50] { return true }
        if data.count >= 8, data.subdata(in: 4..<8) == Data("ftyp".utf8) { return true }
        return false
    }

    private static func normalizedMediaPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "//", with: "/")
            .lowercased()
    }

    /// `https://…/storage/v1/object/sign/{bucket}/{path}?token=`
    private static func storageObject(from url: URL) -> (bucket: String, path: String)? {
        func parsed(after marker: String, skipping skip: Int) -> (String, String)? {
            let parts = url.path.split(separator: "/").map(String.init)
            guard let idx = parts.firstIndex(of: marker), idx + skip + 2 < parts.count else { return nil }
            let rest = Array(parts[(idx + skip)...])
            guard let kind = rest.first, ["sign", "authenticated", "public"].contains(kind),
                  rest.count >= 3 else { return nil }
            let bucket = rest[1]
            let path = rest.dropFirst(2).joined(separator: "/")
            let decoded = path.removingPercentEncoding ?? path
            guard !bucket.isEmpty, !decoded.isEmpty else { return nil }
            return (bucket, decoded)
        }
        if let object = parsed(after: "object", skipping: 1) { return object }
        if url.path.contains("/render/image/"),
           let object = parsed(after: "render", skipping: 2) {
            return object
        }
        return nil
    }

    private func cacheMediaFile(data: Data, path: String) -> URL? {
        let user = currentUserID?.uuidString.lowercased() ?? "anon"
        let safe = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bond-media", isDirectory: true)
            .appendingPathComponent(user, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(safe)
        do {
            try data.write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
    }
}
