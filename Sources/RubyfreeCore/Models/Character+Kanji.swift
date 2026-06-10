public extension Character {
    /// True if the character contains any CJK ideograph (kanji). Used to decide which
    /// tokens deserve a ruby gloss.
    var isKanji: Bool {
        unicodeScalars.contains { s in
            (0x4E00...0x9FFF).contains(s.value)   // CJK Unified Ideographs
                || (0x3400...0x4DBF).contains(s.value)   // Extension A
                || (0xF900...0xFAFF).contains(s.value)   // Compatibility Ideographs
                || (0x20000...0x2FFFF).contains(s.value) // Extensions B–F
        }
    }
}

public extension StringProtocol {
    /// True if the string contains at least one kanji character.
    var containsKanji: Bool { contains { $0.isKanji } }
}
