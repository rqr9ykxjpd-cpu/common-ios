import Foundation

/// Uygulamanın dışarıya verilen bağlantıları.
enum AppLinks {
    /// App Store sayfası. Bölgesiz adres tarayıcıda hata veriyor; Türkiye
    /// mağazası her yerden açılıyor, iPhone'da App Store kişinin mağazasına geçer.
    static let appStore = URL(string: "https://apps.apple.com/tr/app/common/id6805047075")!
}
