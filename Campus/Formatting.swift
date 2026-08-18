import Foundation

extension Date {
    /// Uygulamanın bütün metinleri Türkçe yazılmış durumda. Tarihler ise `Locale.current`
    /// üzerinden biçimleniyordu; yani telefonu İngilizce olan biri Türkçe bir ekranın
    /// ortasında "2 hours ago" görüyordu. Saat biçimi de değişiyordu (11:43 PM / 23:43).
    ///
    /// Uygulama tek dilli olduğu sürece tarihleri de sabitlemek doğru olan. İleride
    /// gerçek lokalizasyon eklenirse buradaki `trTR` kaldırılıp `Locale.current`'a dönülür.
    private static let trTR = Locale(identifier: "tr_TR")

    /// "2 dakika önce", "dün", "5 gün önce"
    var relativeTurkish: String {
        formatted(.relative(presentation: .named).locale(Self.trTR))
    }

    /// "23:43" — Türkiye'de beklenen 24 saatlik biçim.
    var shortTimeTurkish: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Self.trTR))
    }
}
