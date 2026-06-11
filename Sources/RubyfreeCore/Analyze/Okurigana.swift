import Foundation

/// Dictionary-gated okurigana (送り仮名) expansion of a kanji run.
///
/// The capture layer glosses the *maximal kanji run* (``KanjiRun``), but many words carry
/// trailing kana that belong to the word — 宛も (あたかも), 後ろ (うしろ), 自ら (みずから).
/// A kanji run alone (宛) drops that kana, so the analyzer only ever sees 宛 and reads it as
/// あて instead of resolving the whole word.
///
/// The naive fix — "include any trailing hiragana" — is wrong, because okurigana and a
/// following particle are written in the same script: 宛も (the word あたかも) vs 宛＋を (a
/// noun plus the object particle). Only the dictionary can tell them apart. So this extends
/// the run rightward over trailing hiragana **only when the extended surface is a known
/// dictionary word**, choosing the longest such word. A particle is never swallowed because
/// 宛を is not a dictionary entry.
public enum Okurigana {

    /// Cap on the number of trailing hiragana Characters considered. 送り仮名 are short
    /// (typically 1–3); a small cap keeps the membership checks bounded.
    public static let defaultMaxOkurigana = 5

    /// Extend the kanji-run `range` (a UTF-16 `CFRange` into `text`) over trailing hiragana
    /// to the longest dictionary word that starts at the run's start. `isWord` answers
    /// dictionary membership for a candidate surface. Returns the original `range` unchanged
    /// when no trailing hiragana exists or no longer word matches.
    ///
    /// - Parameters:
    ///   - range: A valid kanji-run range (location ≥ 0, length > 0).
    ///   - text: The text the range indexes into.
    ///   - isWord: Membership test — `true` when the surface is a dictionary word.
    ///   - maxOkurigana: Upper bound on trailing hiragana Characters to consider.
    public static func extend(
        range: Range<String.Index>,
        in text: String,
        isWord: (String) -> Bool,
        maxOkurigana: Int = defaultMaxOkurigana
    ) -> Range<String.Index> {
        // Candidate end indices for each trailing hiragana, shortest extension first.
        var candidateEnds: [String.Index] = []
        var cursor = range.upperBound
        while cursor < text.endIndex,
              candidateEnds.count < max(0, maxOkurigana),
              text[cursor].isHiragana {
            cursor = text.index(after: cursor)
            candidateEnds.append(cursor)
        }
        guard !candidateEnds.isEmpty else { return range }

        // Longest match: try the longest extension first; the kana that belong to the word
        // win over a shorter accidental match.
        for end in candidateEnds.reversed() where isWord(String(text[range.lowerBound..<end])) {
            return range.lowerBound..<end
        }
        return range
    }

    /// `CFRange` (UTF-16) overload — used by the AX path, which works in UTF-16 offsets.
    /// Delegates to the `Range<String.Index>` version. Returns the original range when it
    /// can't be resolved into `text`.
    public static func extend(
        range: CFRange,
        in text: String,
        isWord: (String) -> Bool,
        maxOkurigana: Int = defaultMaxOkurigana
    ) -> CFRange {
        let utf16 = text.utf16
        guard range.location >= 0, range.length > 0,
              let start16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex),
              let end16 = utf16.index(start16, offsetBy: range.length, limitedBy: utf16.endIndex),
              let start = start16.samePosition(in: text),
              let end = end16.samePosition(in: text)
        else { return range }

        let extended = extend(range: start..<end, in: text, isWord: isWord, maxOkurigana: maxOkurigana)
        let location = utf16.distance(from: utf16.startIndex, to: extended.lowerBound)
        let length = utf16.distance(from: extended.lowerBound, to: extended.upperBound)
        return CFRange(location: location, length: length)
    }
}
