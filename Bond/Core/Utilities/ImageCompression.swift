import UIKit
import ImageIO

/// Yüklemeden önce fotoğrafı küçültüp sıkıştırır.
///
/// `PhotosPicker` galeriden gelen veriyi ham haliyle veriyor: modern iPhone fotoğrafı
/// 5–12 MB. Storage bucket sınırı 10 MB olduğu için bir kısım yükleme doğrudan hata
/// veriyordu; galeriye 5 fotoğraf koyan biri de ~40 MB gönderiyordu. Kamerayla çekilen
/// sıkıştırılıyordu ama galeriden seçilen sıkıştırılmıyordu — bu tutarsızlık da giderildi.
enum ImageCompression {
    /// Akış ve profil karesi. 3× iPhone genişliği ~1170; üstü RAM’e gider.
    static let maxDimension: CGFloat = 1200
    /// Liste avatarı. 96pt × 3 = 288.
    static let avatarDimension: CGFloat = 320
    /// Hedef dosya boyutu; bucket sınırının (10 MB) belirgin altında tutuluyor.
    static let maxBytes = 1_500_000

    /// Ekranda göstermek için. 12 MP ham bitmap telefonda birkaç karede
    /// jetsam'e gider; uzun kenar `maxDimension` pikselde kalır.
    static func imageForDisplay(_ data: Data, maxDimension: CGFloat = maxDimension) -> UIImage? {
        downsample(data as CFData, maxPixelSize: Int(maxDimension))
    }

    static func imageForDisplay(at url: URL, maxDimension: CGFloat = maxDimension) -> UIImage? {
        downsample(url as CFURL, maxPixelSize: Int(maxDimension))
    }

    static func capped(_ image: UIImage, maxDimension: CGFloat = maxDimension) -> UIImage {
        downscale(image, maxDimension: maxDimension)
    }

    /// Decode etmeden JPEG/PNG başlığından piksel boyutu.
    static func pixelSize(of data: Data) -> CGSize? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, srcOptions as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = props[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }
        return CGSize(width: width.doubleValue, height: height.doubleValue)
    }

    /// Ham görsel verisini yüklemeye uygun JPEG'e çevirir. Çevrilemezse `nil` döner.
    static func prepareForUpload(_ data: Data) -> Data? {
        guard let image = imageForDisplay(data) else { return nil }

        var quality: CGFloat = 0.85
        var output = image.jpegData(compressionQuality: quality)
        // Yüksek çözünürlüklü fotoğraflarda tek geçiş yetmeyebiliyor; sınırın altına
        // inene kadar kaliteyi kademeli düşürüyoruz.
        while let current = output, current.count > maxBytes, quality > 0.4 {
            quality -= 0.15
            output = image.jpegData(compressionQuality: quality)
        }
        return output
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * image.scale * scale, height: image.size.height * image.scale * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func downsample(_ source: CGImageSource, maxPixelSize: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func downsample(_ data: CFData, maxPixelSize: Int) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data, srcOptions as CFDictionary) else { return nil }
        return downsample(source, maxPixelSize: maxPixelSize)
    }

    private static func downsample(_ url: CFURL, maxPixelSize: Int) -> UIImage? {
        let srcOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url, srcOptions as CFDictionary) else { return nil }
        return downsample(source, maxPixelSize: maxPixelSize)
    }
}
