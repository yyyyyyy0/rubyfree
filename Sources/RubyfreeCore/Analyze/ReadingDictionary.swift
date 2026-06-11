import Foundation

/// An in-memory reading dictionary: word-level surfaces (from JMdict) and a per-character
/// fallback (from kanjidic2). Both map a surface to an ordered, de-duplicated list of
/// hiragana readings (primary first).
///
/// This is a pure value type with no I/O, so `DictionaryAnalyzer` can be unit-tested with
/// a small injected dictionary instead of the full bundled resource.
public struct ReadingDictionary: Sendable, Equatable {
    /// Word-level surface → readings (treated as confident matches).
    public let words: [String: [String]]
    /// Single-character → readings (used only as a fallback for unmatched kanji; the
    /// reading is a context-free guess, so callers mark it uncertain).
    public let kanji: [String: [String]]
    /// Longest *word* key, in Characters — bounds the longest-match scan window. Derived
    /// from `words` only; the per-character fallback path is always single-char, so it
    /// intentionally does not factor `kanji` in here.
    public let maxWordLength: Int

    public init(words: [String: [String]], kanji: [String: [String]] = [:]) {
        self.words = words
        self.kanji = kanji
        self.maxWordLength = words.keys.map { $0.count }.max() ?? 1
    }

    /// True when neither table holds any entry.
    public var isEmpty: Bool { words.isEmpty && kanji.isEmpty }
}

// MARK: - TSV loading

public extension ReadingDictionary {
    /// Parse a `surface\tread1,read2,...` TSV body into a `[surface: [readings]]` map.
    /// Malformed lines (no tab, empty surface, no readings) are skipped.
    static func parseTSV(_ body: String) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            let surface = String(line[line.startIndex..<tab])
            let rest = line[line.index(after: tab)...]
            guard !surface.isEmpty else { continue }
            let readings = rest.split(separator: ",").map(String.init).filter { !$0.isEmpty }
            guard !readings.isEmpty else { continue }
            map[surface] = readings
        }
        return map
    }

    /// Build a dictionary from `words.tsv` and `kanji.tsv` bodies.
    init(wordsTSV: String, kanjiTSV: String) {
        self.init(words: Self.parseTSV(wordsTSV), kanji: Self.parseTSV(kanjiTSV))
    }
}
