import Foundation
import UIKit

/// Uzak görseller. Görünüm görevi iptal olsa bile indirme sürer; aynı
/// dosya bir sonraki hücrede önbellekten gelir. Çıkışta sıfırlanır.
///
/// Bellekte tam çözünürlük tutulmaz: decode `ImageCompression` boyutuyla
/// sınırlı, aynı anda en fazla iki indirme, LRU da ~18 MB üstünde eski
/// kareleri atar. Aksi halde akış + story + profil jetsam eder.
actor BondImageLoader {
    static let shared = BondImageLoader()

    private var memory: [String: UIImage] = [:]
    private var order: [String] = []
    private var totalCost = 0
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private var generation: UInt = 0
    private var availableSlots = 2
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private let maxCount = 24
    private let maxCost = 18 * 1024 * 1024
    /// 2 iken hızlı kaydırmada kartlar boş kalıyordu. Çözme boyutu sınırlı ve
    /// görsellerin çoğu artık diskten geliyor; 4 bellek açısından güvenli.
    private let maxConcurrent = 4

    func reset() {
        generation += 1
        inflight.removeAll()
        purgeMemory()
        let pending = waiters
        waiters.removeAll()
        availableSlots = maxConcurrent
        pending.forEach { $0.resume() }
        URLCache.shared.removeAllCachedResponses()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bond-media", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        // Çıkış / hesap değişimi: bir sonraki hesabın önceki kişinin görsellerini
        // diskte bulmaması için kalıcı önbellek de silinir.
        MediaDiskCache.clear()
    }

    func purgeMemory() {
        memory.removeAll()
        order.removeAll()
        totalCost = 0
    }

    func image(
        for url: URL,
        maxDimension: CGFloat = ImageCompression.maxDimension,
        fetch: @escaping @Sendable (URL) async -> Data?
    ) async -> UIImage? {
        let key = "\(Self.cacheKey(for: url))@\(Int(maxDimension))"
        let gen = generation
        if let cached = memory[key] { return gen == generation ? cached : nil }
        if let existing = inflight[key] {
            let image = await existing.value
            return gen == generation ? image : nil
        }
        let diskKey = Self.cacheKey(for: url)
        let task = Task.detached(priority: .utility) { () -> UIImage? in
            // Diskteki kopya ağ kuyruğuna girmeden gelir: açılışta akış anında dolar.
            if !url.isFileURL, MediaDiskCache.isCacheable(diskKey),
               let data = MediaDiskCache.read(diskKey),
               let image = ImageCompression.imageForDisplay(data, maxDimension: maxDimension) {
                return image
            }
            return await BondImageLoader.shared.withConcurrencyLimit {
                if url.isFileURL, let image = ImageCompression.imageForDisplay(at: url, maxDimension: maxDimension) {
                    return image
                }
                guard let data = await fetch(url) else { return nil }
                if MediaDiskCache.isCacheable(diskKey) { MediaDiskCache.write(data, for: diskKey) }
                return ImageCompression.imageForDisplay(data, maxDimension: maxDimension)
            }
        }
        inflight[key] = task
        let image = await task.value
        if inflight[key] != nil { inflight[key] = nil }
        if let image, gen == generation { insert(image, key: key) }
        return gen == generation ? image : nil
    }

    /// Token ve cacheNonce yok: aynı dosyanın yeni imzalı adresi önbelleği vurur.
    nonisolated static func cacheKey(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? url.absoluteString
    }

    fileprivate func withConcurrencyLimit<T: Sendable>(_ work: @Sendable () async -> T) async -> T {
        await acquireSlot()
        let result = await work()
        releaseSlot()
        return result
    }

    private func acquireSlot() async {
        if availableSlots > 0 {
            availableSlots -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func releaseSlot() {
        if waiters.isEmpty {
            availableSlots = min(availableSlots + 1, maxConcurrent)
        } else {
            waiters.removeFirst().resume()
        }
    }

    private func insert(_ image: UIImage, key: String) {
        if let old = memory[key] {
            totalCost -= cost(of: old)
            order.removeAll { $0 == key }
        }
        memory[key] = image
        totalCost += cost(of: image)
        order.append(key)
        while (memory.count > maxCount || totalCost > maxCost), let oldest = order.first {
            order.removeFirst()
            if let removed = memory.removeValue(forKey: oldest) {
                totalCost -= cost(of: removed)
            }
        }
        if totalCost < 0 { totalCost = 0 }
    }

    private func cost(of image: UIImage) -> Int {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        return max(1, Int(width * height * 4))
    }
}
