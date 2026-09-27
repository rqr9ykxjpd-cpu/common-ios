import Foundation

/// Kampüs noktasının simgesi, adından. Sunucudaki yerlerin türü yok; her
/// satırda aynı iğnenin tekrar etmesi bilgi taşımıyordu, bu yüzden adın
/// içindeki kelimeye bakıyoruz. Tanınmayan yer genel iğneyle çıkar.
enum PlaceIcon {
    private static let kurallar: [(kelimeler: [String], simge: String)] = [
        (["kafe", "cafe", "kahve"], "cup.and.saucer"),
        (["kantin", "yemekhane", "restoran", "lokanta"], "fork.knife"),
        (["kütüphane", "kutuphane"], "books.vertical"),
        (["spor", "salon", "fitness", "havuz"], "dumbbell"),
        (["fakülte", "fakulte", "bina", "amfi", "derslik", "rektörlük"], "building.columns"),
        (["otağ", "otag", "çadır"], "tent"),
        (["yurt"], "bed.double"),
        (["park", "bahçe", "çimen"], "leaf"),
    ]

    static func symbol(for name: String) -> String {
        let ad = name.lowercased(with: Locale(identifier: "tr_TR"))
        return kurallar.first { kural in kural.kelimeler.contains { ad.contains($0) } }?.simge ?? "mappin"
    }
}
