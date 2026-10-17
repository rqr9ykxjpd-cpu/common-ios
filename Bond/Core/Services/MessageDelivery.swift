import Foundation

/// "Teslim Edildi", iPhone Mesajlar'daki gibi: mesaj karşı tarafın
/// uygulamasına ulaşınca alıcının uygulaması işaretler, gönderen son
/// mesajının altında görür. Okundu bilgisi gösterilmiyor.
protocol MessageDeliveryMarking: Sendable {
    /// Bana gelen ve henüz işaretlenmemiş bütün mesajları teslim alındı say.
    func markMessagesDelivered() async throws
}
