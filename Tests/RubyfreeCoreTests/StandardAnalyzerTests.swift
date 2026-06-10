import RubyfreeCore
import TinyTest

func testStandardAnalyzer(_ t: TinyTest) {
    let analyzer = StandardAnalyzer()

    // MARK: 空文字列 → 空配列
    t.expectEqual(analyzer.analyze("").count, 0)

    // MARK: 「漢字検定の勉強」
    let tokens = analyzer.analyze("漢字検定の勉強")

    // 空でないことを確認
    t.expectTrue(!tokens.isEmpty, "tokens should not be empty")

    // range と surface の整合: text[token.range] == token.surface
    let source = "漢字検定の勉強"
    for token in tokens {
        t.expectEqual(String(source[token.range]), token.surface)
    }

    // 漢字を含むトークンに reading が付いていること
    let kanjiTokens = tokens.filter { $0.containsKanji }
    t.expectTrue(!kanjiTokens.isEmpty, "there should be at least one kanji-bearing token")
    for token in kanjiTokens {
        t.expectTrue(token.reading != nil, "kanji token '\(token.surface)' should have a reading")
    }

    // 漢字を含むトークンの reading はひらがなのみで構成されている
    for token in kanjiTokens {
        if let r = token.reading {
            let allHiragana = r.hiragana.unicodeScalars.allSatisfy { s in
                (0x3041...0x3096).contains(s.value)   // ひらがな
                    || s.value == 0x30FC               // 長音符
                    || (0x3099...0x309C).contains(s.value) // 結合濁点など
            }
            t.expectTrue(allHiragana, "reading '\(r.hiragana)' for '\(token.surface)' should be hiragana")
        }
    }

    // 「の」などの仮名のみトークンは reading = nil
    let kanaOnlyTokens = tokens.filter { !$0.containsKanji }
    for token in kanaOnlyTokens {
        t.expectTrue(token.reading == nil, "kana-only token '\(token.surface)' should have no reading")
    }

    // MARK: containsKanji の整合
    // 「漢字検定」「勉強」は containsKanji == true
    let surfaces = tokens.map { $0.surface }
    for surface in surfaces {
        let tok = tokens.first { $0.surface == surface }!
        t.expectEqual(tok.containsKanji, surface.containsKanji)
    }

    // MARK: 同形異音語 — isUncertain
    // 「明日の市場」: 「明日」「市場」は isUncertain == true であること
    let homographSource = "明日の市場"
    let homographTokens = analyzer.analyze(homographSource)

    if let ashita = homographTokens.first(where: { $0.surface == "明日" }) {
        t.expectTrue(ashita.reading?.isUncertain == true, "明日 should be uncertain")
    } else {
        // トークナイザが「明日」を分割しない環境でも「明日」を含むトークンがあれば確認
        let merged = homographTokens.first { $0.surface.contains("明日") && $0.containsKanji }
        t.expectTrue(merged?.reading?.isUncertain == true, "token containing 明日 should be uncertain")
    }

    if let ichiba = homographTokens.first(where: { $0.surface == "市場" }) {
        t.expectTrue(ichiba.reading?.isUncertain == true, "市場 should be uncertain")
    } else {
        let merged = homographTokens.first { $0.surface.contains("市場") && $0.containsKanji }
        t.expectTrue(merged?.reading?.isUncertain == true, "token containing 市場 should be uncertain")
    }

    // range と surface の整合（同形異音語）
    for token in homographTokens {
        t.expectEqual(String(homographSource[token.range]), token.surface)
    }

    // MARK: 単一漢字語の読み確認
    let singleKanji = analyzer.analyze("駅")
    if let ekiToken = singleKanji.first {
        t.expectTrue(ekiToken.reading != nil, "駅 should have a reading")
        t.expectEqual(String(singleKanji.first!.surface), String("駅"[singleKanji.first!.range]))
    }
}
