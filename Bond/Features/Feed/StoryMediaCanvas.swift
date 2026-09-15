import SwiftUI

/// Story görseli, izleyicide ve oluştururken **aynı** çizilir: fotoğraf
/// kırpılmadan tam sığar; 9:16'ya uymayan fotoğrafın boşluğunu aynı fotoğrafın
/// bulanık kopyası doldurur. Eskiden izleyici "doldur" diye kırpıyor, composer
/// küçük bir kartta gösteriyordu — kullanıcı paylaştığı şeyi görmüyordu.
struct StoryMediaCanvas: View {
    let url: URL?
    let data: Data?
    var assetName: String? = nil
    var videoURL: URL? = nil
    var isPaused = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let videoURL {
                    StoryVideoCanvas(url: videoURL, isPaused: isPaused)
                } else {
                    // Arka plan: aynı görsel, doldur + bulanık + karartma.
                    ProfileMedia(url: url, data: data, assetName: assetName, kind: .content, contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 28, opaque: true)
                        .overlay(Color.black.opacity(0.35))
                    // Ön plan: tam sığdır, kırpma yok.
                    ProfileMedia(url: url, data: data, assetName: assetName, kind: .content, contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}
