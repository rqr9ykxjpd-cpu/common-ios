import CryptoKit
import Foundation
import os

/// Kalıcı görsel önbelleği (Caches klasöründe, en çok ~150 MB).
///
/// Neden: bellek önbelleği son 24 görseli tutuyordu; uygulama her açılışta ve
/// biraz kaydırıp geri dönünce aynı fotoğraflar Supabase'den yeniden iniyordu.
/// Hem yavaş hem de ücretsiz plandaki aylık trafiği en hızlı yiyen şey buydu.
///
/// Yalnızca yolu değişmeyen kampüs görselleri önbelleğe girer: profil ve gönderi
/// fotoğrafları her yüklemede yeni bir UUID yoluna yazılıyor, yani aynı yol hep
/// aynı dosya. Story (10 saatte silinir), çalışma grubu yer fotoğrafı (aynı yola
/// üzerine yazılıyor) ve diğer kovalar kapsam dışı. Çıkışta tamamen silinir.
enum MediaDiskCache {
    private static let cacheableBuckets = ["/profile-photos/", "/post-media/"]
    private static let byteLimit = 150 * 1024 * 1024
    /// Her bu kadar yazmada bir boyut kontrolü; her yazmada klasörü taramak pahalı.
    private static let trimEvery = 25
    private static let writes = OSAllocatedUnfairLock(initialState: 0)

    static let directory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("bond-media-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// `key`: imza jetonu çıkarılmış adres (bkz. `BondImageLoader.cacheKey`).
    static func isCacheable(_ key: String) -> Bool {
        cacheableBuckets.contains { key.contains($0) }
    }

    static func read(_ key: String) -> Data? {
        let file = fileURL(for: key)
        guard let data = try? Data(contentsOf: file) else { return nil }
        // Son kullanım tarihi: boyut aşılınca en uzun süredir açılmayanlar gider.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return data
    }

    static func write(_ data: Data, for key: String) {
        try? data.write(to: fileURL(for: key), options: .atomic)
        let sayac = writes.withLock { count -> Int in
            count += 1
            return count
        }
        if sayac % trimEvery == 0 { trim() }
    }

    /// En eski dosyalardan başlayarak sınırın altına iner.
    static func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys, options: .skipsHiddenFiles
        ) else { return }
        var entries = files.compactMap { url -> (url: URL, date: Date, size: Int)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.totalFileAllocatedSize ?? 0)
        }
        var total = entries.reduce(0) { $0 + $1.size }
        guard total > byteLimit else { return }
        entries.sort { $0.date < $1.date }
        for entry in entries where total > byteLimit {
            try? FileManager.default.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest)
    }
}
