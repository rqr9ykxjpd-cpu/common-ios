import Foundation

/// Standalone deterministic regression suite; no Supabase credentials or network.
/// swiftc Bond/Core/Services/ContentSafety.swift Tests/ContentSafetyTests.swift -o /tmp/common-content-safety-tests
@main
struct ContentSafetyTests {
    static func main() throws {
        let blocked = [
            "siktir", "SİKTİR!", "S1KT1R", "sik\u{200B}tir", "ＦＵＣＫ",
            "fuck!", "fucking awful", "What an asshole.", "Sen bir orospu çocuğusun",
            "amına koyayım", "AMINA KOYAYIM", "seni öldüreceğim", "seni o\u{308}ldu\u{308}receg\u{306}im",
            "Sana tecavüz edeceğim", "go\ndie", "kill, yourself", "pornhub", "bl0wj0b"
        ]
        let allowed = [
            "", " ", "Selam, kahve içelim mi?", "Merhaba İstanbul!", "Bu çok şık.",
            "Sık görüşelim", "Amina", "This is a pic of my class", "Scunthorpe", "assistance",
            "passion", "Dickens okumayı seviyorum", "Hello, I'm a student.", "fuchsia",
            "Futbol ve masa tenisi", "Sıkış", "Şiddete karşı destek grubumuz var",
            "Kill the process yourself", "A1 B3 0145 2026"
        ]
        var checks = 0
        for text in blocked {
            precondition(ContentSafety.containsBlockedText(text), "Expected blocked input at test \(checks)")
            do {
                try ContentSafety.validate(text)
                preconditionFailure("validate accepted blocked input at test \(checks)")
            } catch ContentSafetyError.blockedText {
                // The typed error contains no user-written text.
            }
            checks += 1
        }
        for text in allowed {
            precondition(!ContentSafety.containsBlockedText(text), "False positive at test \(checks)")
            try ContentSafety.validate(text)
            checks += 1
        }
        try checkServerRuleParity()
        print("Content safety: \(checks) normalization, boundary, phrase and validation cases passed; client/server rule lists match.")
    }

    /// Prevent one side from silently accepting words the other rejects. This
    /// checks the shared rule data, while supabase/tests exercises PostgreSQL's
    /// actual normalization and trigger behavior after the migration is applied.
    private static func checkServerRuleParity() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let swift = try String(contentsOf: root.appendingPathComponent("Bond/Core/Services/ContentSafety.swift"), encoding: .utf8)
        let sql = try String(contentsOf: root.appendingPathComponent("supabase/migrations/20260910120000_content_text_safety.sql"), encoding: .utf8)
        let swiftTokenBlock = try captures(#"blockedTokens: Set<String> = \[([\s\S]*?)\]"#, in: swift).first!
        let sqlTokenBlock = try captures(#"if words && array\[([\s\S]*?)\]"#, in: sql).first!
        let swiftTokens = try Set(captures(#""([a-z]+)""#, in: swiftTokenBlock))
        let sqlTokens = try Set(captures(#"'([a-z]+)'"#, in: sqlTokenBlock))
        precondition(swiftTokens == sqlTokens, "Client/server blocked-token lists have drifted")

        let swiftPhrases = try captures(#"\[((?:"[a-z]+"(?:, )?)+)\]"#, in: swift)
            .map { $0.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: ",", with: "") }
        let sqlPhrases = try captures(#"position\(' ([a-z ]+) ' in sentence\)"#, in: sql)
        precondition(!swiftPhrases.isEmpty && Set(swiftPhrases) == Set(sqlPhrases), "Client/server blocked-phrase lists have drifted")
    }

    private static func captures(_ pattern: String, in text: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
