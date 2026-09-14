import Foundation

extension ContentSafetyError: LocalizedError {
    var errorDescription: String? {
        L10n.isEnglish
            ? "This text may contain abusive or sexually explicit language. Please edit it before sharing."
            : "Bu metin hakaret, tehdit veya cinsel içerikli ifadeler içerebilir. Paylaşmadan önce lütfen düzenle."
    }
}
