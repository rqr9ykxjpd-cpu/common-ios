import Foundation

/// Seçilebilir ilgi alanları.
///
/// Daha önce bu liste hem `OnboardingFlow` hem `ProfileEditorView` içinde ayrı ayrı
/// yazılıydı; birinde değişiklik yapmak diğerini sessizce geride bırakıyordu. Artık
/// tek kaynak.
///
/// Liste bilerek geniş: ortak ilgi hem eşleşme puanını hem "şunu da seviyorsunuz"
/// satırlarını besliyor. On iki seçenekle çoğu kişi aynı üç dört şeyi seçiyor ve
/// herkes birbirine benziyordu.
enum InterestCatalog {
    /// Aynı anda seçilebilecek en fazla ilgi alanı.
    static let maximumSelection = 10
    /// Profilin keşifte görünmesi için gereken en az sayı.
    static let minimumSelection = 3

    static let grouped: [(baslik: String, secenekler: [String])] = [
        ("Kampüs", ["Kütüphane", "Kulüpler", "Gönüllülük", "Münazara", "Staj & kariyer", "Erasmus"]),
        ("Müzik", ["Canlı müzik", "Elektronik", "Rock", "Rap", "Türkçe pop", "Klasik", "Enstrüman çalmak"]),
        ("Sanat", ["Sinema", "Dizi", "Tiyatro", "Sergiler", "Fotoğraf", "Analog fotoğraf", "Tasarım", "Çizim"]),
        ("Spor", ["Koşu", "Bisiklet", "Yüzme", "Fitness", "Futbol", "Basketbol", "Voleybol", "Yoga", "Dağcılık"]),
        ("Dışarıda", ["Kahve", "Kahvaltı", "Sahil yürüyüşü", "Gece yürüyüşü", "Kamp", "Yol gezisi", "Konserler"]),
        ("Kafa dağıtmak", ["Kitaplar", "Podcast", "Oyunlar", "Yemek yapmak", "Kedi & köpek", "Bitkiler", "Bulmaca"]),
        ("Üretmek", ["Yazılım", "Girişim", "Yazmak", "Video", "Sosyal medya", "Yapay zekâ"])
    ]

    /// Düz liste — sıralama gruplarla aynı kalıyor.
    static let all: [String] = grouped.flatMap(\.secenekler)
}
