import SwiftUI

/// Karşılama ekranından açılan hukuki metin.
enum LegalDocumentRoute: String, Identifiable {
    case kosullar, gizlilik

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kosullar: L10n.Legal.terms
        case .gizlilik: L10n.Legal.privacy
        }
    }

    var blocks: [LegalBlock] {
        switch self {
        case .kosullar: L10n.isEnglish ? LegalTexts.terms : LegalTexts.kosullar
        case .gizlilik: L10n.isEnglish ? LegalTexts.privacy : LegalTexts.gizlilik
        }
    }
}
