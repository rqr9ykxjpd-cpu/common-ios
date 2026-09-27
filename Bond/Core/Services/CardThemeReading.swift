import Foundation

/// Bir profilin kart rengini tek başına, hızlıca okur.
///
/// Kart rengi eskiden `fetchPersonDetails` ile birlikte geliyordu; o çağrı
/// fotoğrafların hepsini imzalamadan dönmediği için kart gerçek internette
/// saniyelerce (ya da imzalama takılırsa hiç) beyaz açılıyordu. Tek sütunluk
/// bu sorgu önce dönüyor ve kart doğru renkte açılıyor.
/// `ProductService`'ten ayrı: örnek mod rengi zaten ayrıntılarla birlikte veriyor.
protocol CardThemeReading: Sendable {
    func fetchCardTheme(_ profileID: UUID) async throws -> CardTheme
}
