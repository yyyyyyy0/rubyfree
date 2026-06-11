import Foundation

/// A `JapaneseAnalyzing` implementation backed by a bundled reading dictionary
/// (JMdict word entries + kanjidic2 per-character fallback).
///
/// Segmentation is **longest-match**: at each position the longest dictionary word that
/// starts there wins. This intentionally trades the grammatical accuracy of a full
/// morphological analyser (MeCab-style) for: zero native/networking dependencies, a
/// reproducible bundled dictionary, and direct support for *multiple readings* — the two
/// things this learning tool actually needs. Reading accuracy (the real complaint with
/// the previous tokenizer) comes from the dictionary, not the segmenter.
///
/// Confidence:
///   - A word with a single known reading → certain.
///   - A word with several readings (e.g. 角 → かど／つの) → all shown, marked uncertain.
///   - An unmatched kanji glossed from the per-character fallback → uncertain.
public struct DictionaryAnalyzer: JapaneseAnalyzing {

    private let dictionary: ReadingDictionary
    /// Hard cap on the longest-match window so a pathological dictionary can't make the
    /// scan quadratic in practice. Trade-off: any dictionary word longer than this many
    /// Characters becomes unreachable and falls back to per-character readings. Target
    /// jukujikun/難読 words are ≤4 Characters, far under this, so the clamp is safe.
    private let scanCap: Int

    public init(dictionary: ReadingDictionary, scanCap: Int = 16) {
        self.dictionary = dictionary
        self.scanCap = scanCap
    }

    public func analyze(_ text: String) -> [AnalyzedToken] {
        guard !text.isEmpty, !dictionary.isEmpty else { return [] }

        let maxScan = min(scanCap, max(1, dictionary.maxWordLength))
        var tokens: [AnalyzedToken] = []
        var idx = text.startIndex

        while idx < text.endIndex {
            if let (end, readings) = longestWord(in: text, from: idx, maxScan: maxScan) {
                let surface = String(text[idx..<end])
                let uncertain = readings.count > 1
                tokens.append(AnalyzedToken(
                    surface: surface,
                    reading: Reading(hiragana: readings[0],
                                     alternatives: Array(readings.dropFirst()),
                                     isUncertain: uncertain),
                    range: idx..<end
                ))
                idx = end
                continue
            }

            // No word match: consume a single character.
            let end = text.index(after: idx)
            let ch = String(text[idx..<end])
            let reading: Reading?
            if ch.containsKanji, let fallback = dictionary.kanji[ch], !fallback.isEmpty {
                // Per-character reading is a context-free guess → always uncertain.
                reading = Reading(hiragana: fallback[0],
                                  alternatives: Array(fallback.dropFirst()),
                                  isUncertain: true)
            } else {
                reading = nil
            }
            tokens.append(AnalyzedToken(surface: ch, reading: reading, range: idx..<end))
            idx = end
        }

        return tokens
    }

    /// Find the longest dictionary word starting at `from`. Returns its end index and
    /// readings, or nil if none matches.
    private func longestWord(in text: String, from start: String.Index, maxScan: Int)
        -> (end: String.Index, readings: [String])? {
        var len = maxScan
        while len >= 1 {
            if let end = text.index(start, offsetBy: len, limitedBy: text.endIndex) {
                let candidate = String(text[start..<end])
                if let readings = dictionary.words[candidate] {
                    return (end, readings)
                }
            }
            len -= 1
        }
        return nil
    }
}
