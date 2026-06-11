import Foundation

public extension ReadingDictionary {
    /// Load the dictionary bundled with `RubyfreeCore` (`words.tsv` + `kanji.tsv`).
    ///
    /// Returns `nil` if either resource is missing or unreadable, so the composition
    /// root can fall back to `StandardAnalyzer` rather than crash. Reading is purely
    /// local file I/O — no networking.
    static func bundled() -> ReadingDictionary? {
        guard
            let wordsURL = Bundle.module.url(forResource: "words", withExtension: "tsv"),
            let kanjiURL = Bundle.module.url(forResource: "kanji", withExtension: "tsv"),
            let wordsTSV = try? String(contentsOf: wordsURL, encoding: .utf8),
            let kanjiTSV = try? String(contentsOf: kanjiURL, encoding: .utf8)
        else { return nil }

        let dict = ReadingDictionary(wordsTSV: wordsTSV, kanjiTSV: kanjiTSV)
        return dict.isEmpty ? nil : dict
    }
}
