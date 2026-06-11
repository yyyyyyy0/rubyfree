import Foundation
import RubyfreeCore
import TinyTest

func testKanjiRun(_ t: TinyTest) {
    // ranges(in:) — maximal kanji runs, kana/punctuation split them.
    func runs(_ s: String) -> [String] { KanjiRun.ranges(in: s).map { String(s[$0]) } }

    t.expectEqual(runs("経済学"), ["経済学"])                      // whole 3-char compound stays together
    t.expectEqual(runs("具体的な経済学の話"), ["具体的", "経済学", "話"]) // kana boundaries split runs
    t.expectEqual(runs("量子力学"), ["量子力学"])
    t.expectEqual(runs("ひらがなのみ"), [])                        // no kanji → no runs
    t.expectEqual(runs(""), [])
    t.expectEqual(runs("ABC123"), [])                             // latin/digits are not kanji

    // range(in:utf16Index:) — the run covering a UTF-16 index, nil off-kanji.
    // "の経済学を": indices 0=の 1=経 2=済 3=学 4=を
    let s = "の経済学を"
    // Cursor on 済 (index 2) → covers 経済学 (utf16 loc 1, len 3).
    let mid = KanjiRun.range(in: s, utf16Index: 2)
    t.expectTrue(mid != nil, "index on kanji must yield a run")
    t.expectEqual(mid!.location, 1)
    t.expectEqual(mid!.length, 3)
    // Cursor on leading 経 (index 1) still expands to the full run.
    let head = KanjiRun.range(in: s, utf16Index: 1)
    t.expectEqual(head!.location, 1)
    t.expectEqual(head!.length, 3)
    // Cursor on kana (index 0 = の, index 4 = を) → nil (caller falls back to tokenizer).
    t.expectTrue(KanjiRun.range(in: s, utf16Index: 0) == nil, "kana position → nil")
    t.expectTrue(KanjiRun.range(in: s, utf16Index: 4) == nil, "kana position → nil")
    // Out-of-bounds index → nil.
    t.expectTrue(KanjiRun.range(in: s, utf16Index: 99) == nil, "out-of-range → nil")
    t.expectTrue(KanjiRun.range(in: s, utf16Index: -1) == nil, "negative → nil")
}
