import Foundation

/// Sunucudaki oturumun durumu.
enum SessionHealth: Sendable, Equatable {
    case valid
    /// Yenileme anahtarı geçersiz ya da oturum silinmiş: yeniden giriş şart.
    case lost
    /// Ağ yok ya da sunucu cevap vermedi; oturum hakkında bir şey söylenemez.
    case unknown
}

/// Oturum sessizce düştüğünde (yenileme reddedildiğinde) SDK bunu bildirmiyor;
/// istekler misafir olarak gidiyor ve her dokunuş boşa çıkıyordu. Uygulama bu
/// soruyla oturumun gerçekten bitip bitmediğini öğreniyor.
protocol SessionChecking: Sendable {
    func checkSession() async -> SessionHealth
}
