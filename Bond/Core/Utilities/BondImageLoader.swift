import Foundation
import UIKit

/// Uzak görseller. Görünüm görevi iptal olsa bile indirme sürer; aynı
/// dosya bir sonraki hücrede önbellekten gelir. Çıkışta sıfırlanır.
actor BondImageLoader {
    static let shared = BondImageLoader()

    private var memory: [String: UIImage] = [:]
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private var generation: UInt = 0

    func reset() {
        generation += 1
        inflight.removeAll()
        memory.removeAll()
        URLCache.shared.removeAllCachedResponses()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bond-media", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    func image(for url: URL, fetch: @escaping @Sendable (URL) async -> Data?) async -> UIImage? {
        let key = Self.cacheKey(for: url)
        let gen = generation
        if gen == generation, let cached = memory[key] { return cached }
        if let existing = inflight[key] {
            let image = await existing.value
            return gen == generation ? image : nil
        }
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            if url.isFileURL,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
            guard let data = await fetch(url), let image = UIImage(data: data) else { return nil }
            return image
        }
        inflight[key] = task
        let image = await task.value
        if inflight[key] != nil { inflight[key] = nil }
        if let image, gen == generation { memory[key] = image }
        return gen == generation ? image : nil
    }

    /// Token ve cacheNonce yok: aynı dosyanın yeni imzalı adresi önbelleği vurur.
    nonisolated static func cacheKey(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? url.absoluteString
    }
}
