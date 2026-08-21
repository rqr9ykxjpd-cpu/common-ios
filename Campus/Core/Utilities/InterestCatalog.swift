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

    static func displayGroup(_ id: String) -> String {
        switch id {
        case "Kampüs": L10n.Interest.groupCampus
        case "Müzik": L10n.Interest.groupMusic
        case "Sanat": L10n.Interest.groupArts
        case "Spor": L10n.Interest.groupSports
        case "Dışarıda": L10n.Interest.groupOut
        case "Kafa dağıtmak": L10n.Interest.groupUnwind
        case "Üretmek": L10n.Interest.groupMake
        default: id
        }
    }

    static func displayName(_ id: String) -> String {
        names[id] ?? id
    }

    private static let names: [String: String] = [
        "Kütüphane": L10n.Interest.itemLibrary,
        "Kulüpler": L10n.Interest.itemClubs,
        "Gönüllülük": L10n.Interest.itemVolunteer,
        "Münazara": L10n.Interest.itemDebate,
        "Staj & kariyer": L10n.Interest.itemCareer,
        "Erasmus": L10n.Interest.itemErasmus,
        "Canlı müzik": L10n.Interest.itemLiveMusic,
        "Elektronik": L10n.Interest.itemElectronic,
        "Rock": L10n.Interest.itemRock,
        "Rap": L10n.Interest.itemRap,
        "Türkçe pop": L10n.Interest.itemTurkishPop,
        "Klasik": L10n.Interest.itemClassical,
        "Enstrüman çalmak": L10n.Interest.itemInstrument,
        "Sinema": L10n.Interest.itemCinema,
        "Dizi": L10n.Interest.itemSeries,
        "Tiyatro": L10n.Interest.itemTheatre,
        "Sergiler": L10n.Interest.itemExhibits,
        "Fotoğraf": L10n.Interest.itemPhoto,
        "Analog fotoğraf": L10n.Interest.itemAnalog,
        "Tasarım": L10n.Interest.itemDesign,
        "Çizim": L10n.Interest.itemDrawing,
        "Koşu": L10n.Interest.itemRunning,
        "Bisiklet": L10n.Interest.itemCycling,
        "Yüzme": L10n.Interest.itemSwimming,
        "Fitness": L10n.Interest.itemFitness,
        "Futbol": L10n.Interest.itemFootball,
        "Basketbol": L10n.Interest.itemBasketball,
        "Voleybol": L10n.Interest.itemVolleyball,
        "Yoga": L10n.Interest.itemYoga,
        "Dağcılık": L10n.Interest.itemHiking,
        "Kahve": L10n.Interest.itemCoffee,
        "Kahvaltı": L10n.Interest.itemBreakfast,
        "Sahil yürüyüşü": L10n.Interest.itemCoastWalk,
        "Gece yürüyüşü": L10n.Interest.itemNightWalk,
        "Kamp": L10n.Interest.itemCamping,
        "Yol gezisi": L10n.Interest.itemRoadTrip,
        "Konserler": L10n.Interest.itemConcerts,
        "Kitaplar": L10n.Interest.itemBooks,
        "Podcast": L10n.Interest.itemPodcasts,
        "Oyunlar": L10n.Interest.itemGames,
        "Yemek yapmak": L10n.Interest.itemCooking,
        "Kedi & köpek": L10n.Interest.itemPets,
        "Bitkiler": L10n.Interest.itemPlants,
        "Bulmaca": L10n.Interest.itemPuzzles,
        "Yazılım": L10n.Interest.itemSoftware,
        "Girişim": L10n.Interest.itemStartup,
        "Yazmak": L10n.Interest.itemWriting,
        "Video": L10n.Interest.itemVideo,
        "Sosyal medya": L10n.Interest.itemSocial,
        "Yapay zekâ": L10n.Interest.itemAi,
    ]
}
