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
    func signedURLs(bucket: String, paths: [String]) async -> [String: URL] {
        let uniquePaths = Array(Set(paths.filter { !$0.isEmpty }))
        guard !uniquePaths.isEmpty else { return [:] }
        guard let results = try? await client.storage.from(bucket).createSignedURLs(paths: uniquePaths, expiresIn: 3_600) else {
            // Toplu imza tamamen düşerse tek tek dene — bir path'in hatası
            // diğerlerinin de boş gelmesine yol açmasın.
            return await signedURLsIndividually(bucket: bucket, paths: uniquePaths)
        }
        var map: [String: URL] = [:]
        for result in results {
            if case let .success(path, url) = result {
                map[path] = url
            }
        }
        // Bazı path'ler topluda başarısız olduysa tek tek tamamla.
        let missing = uniquePaths.filter { map[$0] == nil }
        if !missing.isEmpty {
            let extras = await signedURLsIndividually(bucket: bucket, paths: missing)
            for (path, url) in extras { map[path] = url }
        }
        return map
    }

    private func signedURLsIndividually(bucket: String, paths: [String]) async -> [String: URL] {
        var map: [String: URL] = [:]
        for path in paths {
            if let url = try? await client.storage.from(bucket).createSignedURL(path: path, expiresIn: 3_600) {
                map[path] = url
            }
        }
        return map
    }
}
