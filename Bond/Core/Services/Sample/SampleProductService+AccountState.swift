#if DEBUG
import Foundation

/// Örnek modda `-frozen` ile açılırsa hesap dondurulmuş sayılır: ekranı
/// sunucuda kimseyi dondurmadan görmek için.
extension SampleProductService: AccountStateReading {
    func isMyAccountFrozen() async throws -> Bool {
        ProcessInfo.processInfo.arguments.contains("-frozen")
    }
}
#endif
