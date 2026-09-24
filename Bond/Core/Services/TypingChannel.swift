import Foundation

/// Sohbette "yazıyor…" için anlık sinyal kanalı. Kalıcı değil: veritabanına
/// hiçbir şey yazılmaz, yalnızca o an sohbette açık olan karşı tarafa iletilir.
protocol TypingChannel: Sendable {
    /// Karşı taraf her yazdığında (en sık birkaç saniyede bir) bir değer gelir.
    var signals: AsyncStream<Void> { get }
    /// "Ben yazıyorum" sinyali. Çağıran seyreltir; her harfte gönderilmez.
    func ping() async
    func close() async
}
