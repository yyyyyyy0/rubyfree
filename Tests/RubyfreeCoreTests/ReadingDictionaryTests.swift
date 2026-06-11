import RubyfreeCore
import TinyTest

func testReadingDictionary(_ t: TinyTest) {
    let base = ReadingDictionary(
        words: ["山": ["やま"], "川": ["かわ"]],
        kanji: ["山": ["さん", "やま"]]
    )

    // 1. merging with empty user words returns an equivalent dictionary.
    let same = base.merging(words: [:])
    t.expectEqual(same.words["山"] ?? [], ["やま"])

    // 2. A user reading OVERRIDES the bundled one for the same surface.
    let merged = base.merging(words: ["山": ["せん"], "空": ["そら"]])
    t.expectEqual(merged.words["山"] ?? [], ["せん"])   // user reading overrides bundled
    t.expectEqual(merged.words["川"] ?? [], ["かわ"])   // untouched surface kept
    t.expectEqual(merged.words["空"] ?? [], ["そら"])   // new user surface added

    // 3. kanji fallback table is unchanged; maxWordLength recomputed (空 added, len 1).
    t.expectEqual(merged.kanji["山"] ?? [], ["さん", "やま"])
    t.expectTrue(merged.maxWordLength >= 1)

    // 4. The receiver is not mutated (value semantics).
    t.expectEqual(base.words["山"] ?? [], ["やま"])   // original dictionary unchanged
}
