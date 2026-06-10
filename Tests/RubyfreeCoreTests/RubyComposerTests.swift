import RubyfreeCore
import TinyTest

func testRubyComposer(_ t: TinyTest) {
    let composer = RubyComposer()

    // Helper to create a dummy range inside a constant string.
    let dummy = "dummy"
    let dummyRange = dummy.startIndex..<dummy.endIndex

    // ------------------------------------------------------------------
    // 1. A token with kanji + reading → should become a RubyRun.
    // ------------------------------------------------------------------
    let kanjiToken = AnalyzedToken(
        surface: "漢字",
        reading: Reading(hiragana: "かんじ", isUncertain: false),
        range: dummyRange
    )
    let resultSingle = composer.compose([kanjiToken])
    t.expectEqual(resultSingle.count, 1)
    t.expectEqual(resultSingle.first, RubyRun(base: "漢字", ruby: "かんじ", isUncertain: false))

    // ------------------------------------------------------------------
    // 2. A kana-only token (no kanji) → skipped.
    // ------------------------------------------------------------------
    let kanaToken = AnalyzedToken(
        surface: "です",
        reading: Reading(hiragana: "です"),
        range: dummyRange
    )
    let resultKana = composer.compose([kanaToken])
    t.expectEqual(resultKana.count, 0)

    // ------------------------------------------------------------------
    // 3. A kanji token with nil reading → skipped.
    // ------------------------------------------------------------------
    let noReadingToken = AnalyzedToken(
        surface: "漢字",
        reading: nil,
        range: dummyRange
    )
    let resultNoReading = composer.compose([noReadingToken])
    t.expectEqual(resultNoReading.count, 0)

    // ------------------------------------------------------------------
    // 4. isUncertain is propagated correctly.
    // ------------------------------------------------------------------
    let uncertainToken = AnalyzedToken(
        surface: "行",
        reading: Reading(hiragana: "いく", isUncertain: true),
        range: dummyRange
    )
    let resultUncertain = composer.compose([uncertainToken])
    t.expectEqual(resultUncertain.count, 1)
    t.expectTrue(resultUncertain.first?.isUncertain == true, "isUncertain should be true")
    t.expectEqual(resultUncertain.first?.ruby, "いく")

    // ------------------------------------------------------------------
    // 5. Mixed tokens: order is preserved, non-kanji/nil-reading skipped.
    // ------------------------------------------------------------------
    let mixed: [AnalyzedToken] = [
        AnalyzedToken(surface: "私", reading: Reading(hiragana: "わたし"), range: dummyRange),
        AnalyzedToken(surface: "は", reading: Reading(hiragana: "は"), range: dummyRange),
        AnalyzedToken(surface: "学校", reading: Reading(hiragana: "がっこう"), range: dummyRange),
        AnalyzedToken(surface: "で", reading: nil, range: dummyRange),
        AnalyzedToken(surface: "勉強", reading: Reading(hiragana: "べんきょう"), range: dummyRange),
    ]
    let resultMixed = composer.compose(mixed)
    t.expectEqual(resultMixed.count, 3)
    t.expectEqual(resultMixed[0], RubyRun(base: "私", ruby: "わたし"))
    t.expectEqual(resultMixed[1], RubyRun(base: "学校", ruby: "がっこう"))
    t.expectEqual(resultMixed[2], RubyRun(base: "勉強", ruby: "べんきょう"))

    // ------------------------------------------------------------------
    // 6. Empty input → empty output.
    // ------------------------------------------------------------------
    t.expectEqual(composer.compose([]).count, 0)
}
