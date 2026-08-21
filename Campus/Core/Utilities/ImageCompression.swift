import UIKit

/// Yüklemeden önce fotoğrafı küçültüp sıkıştırır.
///
/// `PhotosPicker` galeriden gelen veriyi ham haliyle veriyor: modern iPhone fotoğrafı
/// 5–12 MB. Storage bucket sınırı 10 MB olduğu için bir kısım yükleme doğrudan hata
/// veriyordu; galeriye 5 fotoğraf koyan biri de ~40 MB gönderiyordu. Kamerayla çekilen
/// sıkıştırılıyordu ama galeriden seçilen sıkıştırılmıyordu — bu tutarsızlık da giderildi.
enum ImageCompression {
    /// Uzun kenar için üst sınır. Telefon ekranında gösterilen en büyük görsel bunun
    /// altında kaldığı için daha büyüğünü saklamanın görsel bir karşılığı yok.
    static let maxDimension: CGFloat = 1600
    /// Hedef dosya boyutu; bucket sınırının (10 MB) belirgin altında tutuluyor.
    static let maxBytes = 1_500_000

    /// Ham görsel verisini yüklemeye uygun JPEG'e çevirir. Çevrilemezse `nil` döner.
    static func prepareForUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = downscale(image, maxDimension: maxDimension)

        var quality: CGFloat = 0.85
        var output = resized.jpegData(compressionQuality: quality)
        // Yüksek çözünürlüklü fotoğraflarda tek geçiş yetmeyebiliyor; sınırın altına
        // inene kadar kaliteyi kademeli düşürüyoruz.
        while let current = output, current.count > maxBytes, quality > 0.4 {
            quality -= 0.15
            output = resized.jpegData(compressionQuality: quality)
        }
        return output
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
