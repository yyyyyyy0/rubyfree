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

public extension Character {
    /// True if the character is a hiragana letter (the script okurigana is written in).
    /// Used by ``Okurigana`` to extend a kanji run over trailing 送り仮名.
    var isHiragana: Bool {
        guard !unicodeScalars.isEmpty else { return false }
        // U+3041…U+3096 hiragana letters, plus U+309D…U+309F iteration/digraph marks.
        return unicodeScalars.allSatisfy { s in
            (0x3041...0x3096).contains(s.value) || (0x309D...0x309F).contains(s.value)
        }
    }
}

public extension StringProtocol {
    /// True if the string contains at least one kanji character.
    var containsKanji: Bool { contains { $0.isKanji } }
}
