import Foundation
import RubyfreeCore
import TinyTest

func testOkurigana(_ t: TinyTest) {
    // UTF-16 CFRange covering the leading kanji run of `text`.
    func runRange(_ text: String, kanji: String) -> CFRange {
        let ns = text as NSString
        return ns.range(of: kanji).toCF
    }

    // ------------------------------------------------------------------
    // 1. Extends over okurigana when the extended surface is a dictionary word.
    //    宛 (run) + も → 宛も is a word ⇒ range grows to cover 宛も.
    // ------------------------------------------------------------------
    let words: Set<String> = ["宛も", "後ろ", "宛もどき"]
    let isWord: (String) -> Bool = { words.contains($0) }

    let text1 = "宛も"
    let r1 = Okurigana.extend(range: runRange(text1, kanji: "宛"), in: text1, isWord: isWord)
    t.expectEqual(substring(text1, r1), "宛も")

    // ------------------------------------------------------------------
    // 2. Does NOT extend over a following particle (same kana, not a word).
    //    宛 + を → 宛を is not a word ⇒ range stays at 宛.
    // ------------------------------------------------------------------
    let text2 = "宛を"
    let r2 = Okurigana.extend(range: runRange(text2, kanji: "宛"), in: text2, isWord: isWord)
    t.expectEqual(substring(text2, r2), "宛")

    // ------------------------------------------------------------------
    // 3. Longest match: prefer the longer dictionary word when both match.
    //    宛もどき & 宛も are both words ⇒ pick 宛もどき.
    // ------------------------------------------------------------------
    let text3 = "宛もどき"
    let r3 = Okurigana.extend(range: runRange(text3, kanji: "宛"), in: text3, isWord: isWord)
    t.expectEqual(substring(text3, r3), "宛もどき")

    // ------------------------------------------------------------------
    // 4. Trailing kana followed by more text: stops at the longest word, leaving the rest.
    //    後ろ is a word; 後ろから… ⇒ range covers 後ろ only.
    // ------------------------------------------------------------------
    let text4 = "後ろから"
    let r4 = Okurigana.extend(range: runRange(text4, kanji: "後"), in: text4, isWord: isWord)
    t.expectEqual(substring(text4, r4), "後ろ")

    // ------------------------------------------------------------------
    // 5. No trailing hiragana → unchanged (kanji compound, next char is kanji).
    // ------------------------------------------------------------------
    let text5 = "宛先"
    let r5 = Okurigana.extend(range: runRange(text5, kanji: "宛"), in: text5, isWord: isWord)
    t.expectEqual(substring(text5, r5), "宛")

    // ------------------------------------------------------------------
    // 6. Trailing katakana is not okurigana → unchanged.
    // ------------------------------------------------------------------
    let text6 = "宛モ"
    let r6 = Okurigana.extend(range: runRange(text6, kanji: "宛"), in: text6, isWord: isWord)
    t.expectEqual(substring(text6, r6), "宛")

    // ------------------------------------------------------------------
    // 7. maxOkurigana caps the window: with cap 1, 宛もどき can't be reached, but 宛も can.
    // ------------------------------------------------------------------
    let cap1 = Okurigana.extend(range: runRange(text3, kanji: "宛"), in: text3, isWord: isWord, maxOkurigana: 1)
    t.expectEqual(substring(text3, cap1), "宛も")

    // ------------------------------------------------------------------
    // 7b. String.Index overload (used by the OCR path) behaves identically: extends 宛 → 宛も
    //     inside a longer line, and leaves a particle alone.
    // ------------------------------------------------------------------
    let line = "彼は宛もどき後ろを見た"
    if let kr = line.range(of: "宛") {
        let ext = Okurigana.extend(range: kr, in: line, isWord: isWord)
        t.expectEqual(String(line[ext]), "宛もどき")
    } else {
        t.expectTrue(false, "setup: 宛 must be found in line")
    }
    if let kr = line.range(of: "後") {
        let ext = Okurigana.extend(range: kr, in: line, isWord: isWord)  // 後ろ word, を particle
        t.expectEqual(String(line[ext]), "後ろ")
    } else {
        t.expectTrue(false, "setup: 後 must be found in line")
    }

    // ------------------------------------------------------------------
    // 8. End-to-end with the REAL bundled dictionary: capturing 宛 + okurigana resolves the
    //    whole word reading (宛も → あたかも) instead of the bare-kanji reading.
    // ------------------------------------------------------------------
    if let dict = ReadingDictionary.bundled() {
        let analyzer = DictionaryAnalyzer(dictionary: dict)
        let member: (String) -> Bool = { dict.words[$0] != nil }

        let window = "宛も"
        let extended = Okurigana.extend(range: runRange(window, kanji: "宛"), in: window, isWord: member)
        let surface = substring(window, extended)
        t.expectEqual(surface, "宛も")

        // The analyzer reads the extended surface as the whole word.
        let tokens = analyzer.analyze(surface)
        t.expectTrue(tokens.first?.reading?.hiragana == "あたかも",
                     "宛も must read あたかも (got \(tokens.first?.reading?.hiragana ?? "nil"))")

        // Bare kanji run reads differently (proves the extension is what fixes it).
        let bare = analyzer.analyze("宛")
        t.expectTrue(bare.first?.reading?.hiragana != "あたかも",
                     "bare 宛 must NOT read あたかも")
    }
}

// MARK: - Helpers

private func substring(_ text: String, _ range: CFRange) -> String {
    (text as NSString).substring(with: NSRange(location: range.location, length: range.length))
}

private extension NSRange {
    var toCF: CFRange { CFRange(location: location, length: length) }
}
