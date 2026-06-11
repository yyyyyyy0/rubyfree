import Foundation

/// Pure logic for finding the *maximal run of consecutive kanji* in text.
///
/// This is the unit rubyfree captures and glosses. A word-boundary tokenizer
/// (`CFStringTokenizer`) splits compounds — 経済学 → 経済 | 学, 量子力学 → 量子 | 力学 —
/// so if the capture layer used tokenizer words it would hand the analyzer a fragment and
/// never gloss the full compound, even though the dictionary holds 経済学 → けいざいがく.
/// Keeping the whole kanji run together lets the dictionary's longest-match resolve it as
/// one word (and still split a non-dictionary concatenation sensibly).
public enum KanjiRun {

    /// The maximal consecutive-kanji run (as a UTF-16 `CFRange`) covering `utf16Index`,
    /// or `nil` if the character at that index is not a kanji. Mirrors
    /// ``WordBoundary/wordRange(in:utf16Index:)`` so the AX path can prefer a kanji run and
    /// fall back to a tokenizer word for non-kanji positions.
    public static func range(in text: String, utf16Index: Int) -> CFRange? {
        let utf16 = text.utf16
        guard utf16Index >= 0, utf16Index < utf16.count,
              let center16 = utf16.index(utf16.startIndex, offsetBy: utf16Index, limitedBy: utf16.endIndex),
              let center = center16.samePosition(in: text),
              center < text.endIndex,
              text[center].isKanji
        else { return nil }

        var lower = center
        while lower > text.startIndex {
            let prev = text.index(before: lower)
            if text[prev].isKanji { lower = prev } else { break }
        }
        var upper = text.index(after: center)
        while upper < text.endIndex, text[upper].isKanji {
            upper = text.index(after: upper)
        }

        let location = utf16.distance(from: utf16.startIndex, to: lower)
        let length = utf16.distance(from: lower, to: upper)
        return CFRange(location: location, length: length)
    }

    /// All maximal consecutive-kanji runs in `text`, in order. Used by the OCR path to turn
    /// a recognized line into glossable candidate spans (kana / punctuation separate runs).
    public static func ranges(in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var i = text.startIndex
        while i < text.endIndex {
            guard text[i].isKanji else {
                i = text.index(after: i)
                continue
            }
            var j = text.index(after: i)
            while j < text.endIndex, text[j].isKanji { j = text.index(after: j) }
            result.append(i..<j)
            i = j
        }
        return result
    }
}
