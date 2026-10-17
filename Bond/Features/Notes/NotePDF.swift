import PDFKit
import UIKit

/// Notun dosya işleri: fotoğraf sayfalarından PDF, PDF'in kapak resmi, dosya adı.
enum NotePDF {
    /// Sayfa resimlerinden PDF; her sayfa kendi oranında, genişlik A4 (595 pt).
    /// Arka planda ve sayfa sayfa: 20 fotoğraf aynı anda açılınca bellek dolar.
    static func make(pages: [Data]) async -> Data? {
        guard !pages.isEmpty else { return nil }
        return await Task.detached(priority: .userInitiated) {
            var yazilan = 0
            let veri = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { ctx in
                for sayfa in pages {
                    autoreleasepool {
                        guard let resim = ImageCompression.imageForDisplay(sayfa, maxDimension: ImageCompression.notePageDimension),
                              resim.size.width > 0 else { return }
                        let boyut = CGSize(width: 595, height: (595 * resim.size.height / resim.size.width).rounded())
                        ctx.beginPage(withBounds: CGRect(origin: .zero, size: boyut), pageInfo: [:])
                        resim.draw(in: CGRect(origin: .zero, size: boyut))
                        yazilan += 1
                    }
                }
            }
            return yazilan > 0 ? veri : nil
        }.value
    }

    /// İlk sayfanın resmi: akışta ve eski sürümlerde notun yüzü.
    @MainActor
    static func cover(of document: PDFDocument) -> Data? {
        guard let ilk = document.page(at: 0) else { return nil }
        let resim = ilk.thumbnail(of: CGSize(width: 1200, height: 1600), for: .mediaBox)
        // Saydam sayfa JPEG'de siyaha dönmesin.
        let beyaz = UIGraphicsImageRenderer(size: resim.size, format: {
            let f = UIGraphicsImageRendererFormat.default(); f.scale = 1; f.opaque = true; return f
        }()).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: resim.size))
            resim.draw(at: .zero)
        }
        return beyaz.jpegData(compressionQuality: 0.8)
    }

    /// Paylaşılan dosyanın adı: "BLM203 Veri Yapıları - Hash tabloları.pdf".
    static func fileName(course: String, title: String) -> String {
        let parcalar = [course, title].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var ad = Array(Set(parcalar)).count == 1 ? parcalar[0] : parcalar.filter { !$0.isEmpty }.joined(separator: " - ")
        ad = ad.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>\n")).joined(separator: "-")
        if ad.isEmpty { ad = L10n.Notes.title }
        return String(ad.prefix(80)) + ".pdf"
    }
}
