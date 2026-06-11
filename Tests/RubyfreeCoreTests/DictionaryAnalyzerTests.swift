import Foundation
import RubyfreeCore
import TinyTest

func testDictionaryAnalyzer(_ t: TinyTest) {
    // A small injected dictionary — no dependency on the full bundled JMdict.
    let dict = ReadingDictionary(
        words: [
            "海月": ["くらげ"],            // jukujikun — the headline accuracy case
            "学校": ["がっこう"],
            "角": ["かど", "つの"],        // multiple readings
            "日本": ["にほん", "にっぽん"],
        ],
        kanji: [
            "水": ["みず", "すい"],        // per-character fallback
        ]
    )
    let analyzer = DictionaryAnalyzer(dictionary: dict)

    // 1. Empty input → no tokens.
    t.expectEqual(analyzer.analyze("").count, 0)

    // 2. Jukujikun word resolves to the correct reading (the previous tokenizer failed here).
    let kurage = analyzer.analyze("海月")
    t.expectEqual(kurage.count, 1)
    t.expectEqual(kurage.first?.surface, "海月")
    t.expectEqual(kurage.first?.reading?.hiragana, "くらげ")
    t.expectTrue(kurage.first?.reading?.isUncertain == false, "single-reading word is certain")

    // 3. Multiple readings are surfaced as alternatives and flagged uncertain.
    let kado = analyzer.analyze("角")
    t.expectEqual(kado.first?.reading?.hiragana, "かど")
    t.expectEqual(kado.first?.reading?.alternatives, ["つの"])
    t.expectTrue(kado.first?.reading?.isUncertain == true, "ambiguous word is uncertain")
    t.expectEqual(kado.first?.reading?.allReadings, ["かど", "つの"])

    // 4. Longest-match: 学校 (a word) wins over consuming 学 then 校 separately.
    let school = analyzer.analyze("学校")
    t.expectEqual(school.count, 1)
    t.expectEqual(school.first?.surface, "学校")
    t.expectEqual(school.first?.reading?.hiragana, "がっこう")

    // 5. Mixed text: kanji word + kana tail. Kana characters get no reading.
    let mixed = analyzer.analyze("海月です")
    t.expectEqual(mixed.first?.surface, "海月")
    t.expectEqual(mixed.first?.reading?.hiragana, "くらげ")
    // Every kana character after the word is its own reading-less token.
    let tail = mixed.dropFirst()
    t.expectTrue(tail.allSatisfy { $0.reading == nil }, "kana tail must carry no reading")
    t.expectEqual(tail.map(\.surface).joined(), "です")

    // 6. Per-character fallback for an unmatched kanji, marked uncertain.
    let water = analyzer.analyze("水")
    t.expectEqual(water.first?.reading?.hiragana, "みず")
    t.expectTrue(water.first?.reading?.isUncertain == true, "per-char fallback is uncertain")

    // 7. Unknown kanji with no fallback → token present but reading nil.
    let unknown = analyzer.analyze("鬱")
    t.expectEqual(unknown.count, 1)
    t.expectTrue(unknown.first?.reading == nil, "unknown kanji has no reading")

    // 8. Empty dictionary → no tokens (defensive: missing bundled resource).
    let empty = DictionaryAnalyzer(dictionary: ReadingDictionary(words: [:]))
    t.expectEqual(empty.analyze("海月").count, 0)

    // 9. TSV round-trip parsing.
    let parsed = ReadingDictionary(wordsTSV: "海月\tくらげ\n角\tかど,つの\n", kanjiTSV: "水\tみず,すい\n")
    t.expectEqual(parsed.words["海月"], ["くらげ"])
    t.expectEqual(parsed.words["角"], ["かど", "つの"])
    t.expectEqual(parsed.kanji["水"], ["みず", "すい"])
    // Malformed lines are skipped.
    let malformed = ReadingDictionary.parseTSV("nodelim\n\tnosurfacekey\n海\t\n良\tよい\n")
    t.expectEqual(malformed.count, 1)
    t.expectEqual(malformed["良"], ["よい"])

    // 10. End-to-end: the BUNDLED dictionary loads and resolves real jukujikun. This
    //     exercises Bundle.module resource loading, not just an injected fixture.
    if let real = ReadingDictionary.bundled() {
        t.expectTrue(real.words.count > 100_000, "bundled words.tsv should hold the full JMdict")
        let realAnalyzer = DictionaryAnalyzer(dictionary: real)
        t.expectEqual(realAnalyzer.analyze("海月").first?.reading?.hiragana, "くらげ")
        t.expectEqual(realAnalyzer.analyze("紫陽花").first?.reading?.hiragana, "あじさい")
    } else {
        t.expectTrue(false, "bundled dictionary must be loadable from Bundle.module")
    }
}
