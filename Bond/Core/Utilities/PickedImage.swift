import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Galeriden seçilen öğenin görseli.
///
/// `loadTransferable(type: Data.self)` öğenin ilk biçimini getiriyordu. Canlı
/// fotoğrafta bu, fotoğrafın kendisi değil fotoğraf + video paketi; görsel
/// olarak çözülemiyordu. Story'de öğe video sanılıp hareketli kısmı
/// yükleniyordu (uzun bekleme, "Video yükleniyor"); diğer ekranlarda
/// "fotoğraf yüklenemedi" çıkıyordu. Burada açıkça görsel biçimi isteniyor;
/// HEIC de olsa sıkıştırma onu JPEG'e çeviriyor.
extension PhotosPickerItem {
    func loadImageData() async throws -> Data? {
        try await loadTransferable(type: PickedImageData.self)?.data
    }

    /// Görseli var mı (canlı fotoğraf dahil). Yalnızca video olan öğede `false`.
    var hasImage: Bool {
        supportedContentTypes.contains { $0.conforms(to: .image) || $0.conforms(to: .livePhoto) }
    }
}

private struct PickedImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { PickedImageData(data: $0) }
    }
}
