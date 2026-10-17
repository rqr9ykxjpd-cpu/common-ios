#if DEBUG
import Foundation

/// Örnek modda karşı taraf yok; teslimi `-incoming` taklit ediyor
/// (bkz. `SampleIncoming`).
extension SampleProductService: MessageDeliveryMarking {
    func markMessagesDelivered() async throws {}
}
#endif
