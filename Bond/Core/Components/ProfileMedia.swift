import SwiftUI
import UIKit

struct ProfileMedia: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let assetName {
                Image(assetName).resizable().scaledToFill()
            } else if let url {
                RemoteProfileImage(url: url)
            } else {
                profilePhotoFallback
            }
        }
    }
}

/// `AppState` burada yok: Observable her yenilemede görevi iptal edip
/// fotoğrafı boş bırakıyordu. Adres varsa doğrudan indirilir; aynı URL
/// bir sonraki kartta önbellekten gelir.
private struct RemoteProfileImage: View {
    let url: URL
    @State private var image: UIImage?
    @State private var finished = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !finished {
                BondTheme.ink.opacity(0.08)
            } else {
                profilePhotoFallback
            }
        }
        .task(id: BondImageLoader.cacheKey(for: url)) {
            let loaded = await BondImageLoader.shared.image(for: url) { target in
                await Self.loadData(target)
            }
            image = loaded
            finished = true
        }
    }

    private static func loadData(_ url: URL) async -> Data? {
        if url.isFileURL {
            return try? Data(contentsOf: url)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            #if DEBUG
            print("Bond media GET ağ hatası \(url.absoluteString.prefix(120))")
            #endif
            return nil
        }
        guard let http = response as? HTTPURLResponse else { return nil }
        #if DEBUG
        if !(200...299).contains(http.statusCode) {
            print("Bond media GET \(http.statusCode) \(url.absoluteString.prefix(160))")
        }
        #endif
        guard (200...299).contains(http.statusCode), !data.isEmpty else { return nil }
        return data
    }
}

private var profilePhotoFallback: some View {
    LinearGradient(colors: [BondTheme.violet.opacity(0.9), BondTheme.coral.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.35)))
}
