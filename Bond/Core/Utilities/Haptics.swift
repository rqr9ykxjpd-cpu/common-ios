import UIKit

@MainActor
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Oy. Üç durum elde farklı hissedilir: ▲ dolgun ve net, ▼ daha yumuşak,
    /// oyu geri almak yalnızca bir seçim tıkı (kutlanacak bir şey değil).
    /// Eskiden üçü de aynı hafif darbeydi. Üreteçler her dokunuştan sonra
    /// hazırda tutuluyor; art arda oylarda titreşim gecikmiyor.
    static func vote(_ value: Int) {
        switch value {
        case 1:
            upvote.impactOccurred(intensity: 0.9)
            upvote.prepare()
        case -1:
            downvote.impactOccurred(intensity: 0.7)
            downvote.prepare()
        default:
            selection()
        }
    }

    private static let upvote = UIImpactFeedbackGenerator(style: .medium)
    private static let downvote = UIImpactFeedbackGenerator(style: .soft)
}
