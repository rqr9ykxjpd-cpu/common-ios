import Foundation

/// A narrow, deterministic pre-publication text check, not a contextual AI moderator.
/// Keep these rules aligned with `20260910120000_content_text_safety.sql`.
/// Whole tokens avoid blocking innocent words such as "sık", "class" or "Scunthorpe".
enum ContentSafety {
    private static let blockedTokens: Set<String> = [
        "amk", "amq", "aminakoyayim", "aminakoyim", "amcik",
        "orospu", "orospuoglu", "siktir", "siktirin", "siktirgit",
        "sikerim", "sikeriz", "sikeyim", "sikeyin", "sikicem", "sikecegim",
        "sikiyorum", "sikismek", "yarrak", "yarragi", "gotsiken",
        "fuck", "fucking", "fucked", "fucker", "fuckers", "fuckoff",
        "motherfucker", "motherfuckers", "motherfucking", "cunt", "cunts",
        "asshole", "assholes", "dickhead", "dickheads", "bullshit",
        "porn", "porno", "pornhub", "pornography", "pornographic",
        "blowjob", "blowjobs", "handjob", "handjobs"
    ]

    private static let blockedPhrases = [
        ["amina", "koyayim"], ["amina", "koyim"],
        ["kill", "yourself"], ["go", "die"],
        ["seni", "oldurecegim"], ["seni", "oldururum"],
        ["sana", "tecavuz", "edecegim"]
    ]

    static func validate(_ text: String) throws {
        if containsBlockedText(text) { throw ContentSafetyError.blockedText }
    }

    static func containsBlockedText(_ text: String) -> Bool {
        let words = tokens(text)
        if words.contains(where: blockedTokens.contains) { return true }
        return blockedPhrases.contains { phrase in
            guard words.count >= phrase.count else { return false }
            return (0...(words.count - phrase.count)).contains { start in
                Array(words[start..<(start + phrase.count)]) == phrase
            }
        }
    }

    private static func tokens(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCompatibilityMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        let source = Array("çğıöşüâîûÇĞİÖŞÜÂÎÛ")
        let destination = Array("cgiosuaiuCGIOSUAIU")
        let replacements = Dictionary(uniqueKeysWithValues: zip(source, destination))
        let ignored: Set<Unicode.Scalar> = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{2060}", "\u{FEFF}", "\u{0307}"]
        let visible = String(normalized.unicodeScalars.filter { !ignored.contains($0) })
        let folded = String(visible.map { replacements[$0] ?? $0 }).lowercased()
        let digitSubstitutions: [Character: Character] = ["0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t"]
        return folded.unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }.map { part in
            String(String(String.UnicodeScalarView(part)).map { digitSubstitutions[$0] ?? $0 })
        }
    }
}

/// Never includes the rejected content: errors can be recorded by the debug logger.
enum ContentSafetyError: Error {
    case blockedText
}
