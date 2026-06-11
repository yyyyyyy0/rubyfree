import Foundation
import CoreText
import CoreGraphics
import RubyfreeCore
import TinyTest

func testRubyAttributedBuilder(_ t: TinyTest) {
    let builder = RubyAttributedBuilder()

    // ------------------------------------------------------------------
    // 1. Empty input → empty attributed string (length == 0).
    // ------------------------------------------------------------------
    let empty = builder.build([])
    t.expectEqual(empty.length, 0)

    // ------------------------------------------------------------------
    // 2. Single certain run:
    //    - result.length > 0
    //    - base string is present in the output
    //    - kCTRubyAnnotationAttributeName attribute exists at position 0
    // ------------------------------------------------------------------
    let runs: [RubyRun] = [RubyRun(base: "漢字", ruby: "かんじ")]
    let attrStr = builder.build(runs)

    t.expectTrue(attrStr.length > 0, "attributed string must be non-empty")

    // The base text must appear somewhere in the attributed string.
    t.expectTrue(
        attrStr.string.contains("漢字"),
        "base string '漢字' must be present in the attributed string"
    )

    // kCTRubyAnnotationAttributeName must be set on the base characters.
    var effectiveRange = NSRange(location: 0, length: 0)
    let rubyAttr = attrStr.attribute(
        kCTRubyAnnotationAttributeName as NSAttributedString.Key,
        at: 0,
        effectiveRange: &effectiveRange
    )
    t.expectTrue(rubyAttr != nil, "kCTRubyAnnotationAttributeName must be non-nil at position 0")

    // ------------------------------------------------------------------
    // 3. Uncertain run:
    //    - result.length > 0
    //    - kCTRubyAnnotationAttributeName present
    //    - foreground color differs from a certain run (uncertain uses grey)
    // ------------------------------------------------------------------
    let uncertainRuns: [RubyRun] = [RubyRun(base: "行", ruby: "いく", isUncertain: true)]
    let uncertainStr = builder.build(uncertainRuns)

    t.expectTrue(uncertainStr.length > 0, "uncertain run must produce non-empty string")

    var uncertainRubyRange = NSRange(location: 0, length: 0)
    let uncertainRubyAttr = uncertainStr.attribute(
        kCTRubyAnnotationAttributeName as NSAttributedString.Key,
        at: 0,
        effectiveRange: &uncertainRubyRange
    )
    t.expectTrue(uncertainRubyAttr != nil, "kCTRubyAnnotationAttributeName must be present for uncertain run")

    // New contract: the *base* (kanji) keeps the high-contrast foreground colour in both
    // certain and uncertain runs so the body text stays readable; the uncertainty signal
    // is carried by the ruby (furigana) colour, not the base. Verify the base colour at
    // position 0 is the configured `foregroundColor` regardless of `isUncertain`.
    let certainStr = builder.build([RubyRun(base: "行", ruby: "いく", isUncertain: false)])
    let certainColor = certainStr.attribute(
        kCTForegroundColorAttributeName as NSAttributedString.Key,
        at: 0,
        effectiveRange: nil
    ) as! CGColor
    let uncertainColor = uncertainStr.attribute(
        kCTForegroundColorAttributeName as NSAttributedString.Key,
        at: 0,
        effectiveRange: nil
    ) as! CGColor
    t.expectEqual(certainColor, RubyStyle().foregroundColor)
    t.expectEqual(uncertainColor, RubyStyle().foregroundColor)

    // ------------------------------------------------------------------
    // 4. Multiple runs: all bases present, ruby annotation on each base.
    // ------------------------------------------------------------------
    let multiRuns: [RubyRun] = [
        RubyRun(base: "私", ruby: "わたし"),
        RubyRun(base: "学校", ruby: "がっこう"),
    ]
    let multiStr = builder.build(multiRuns)
    t.expectTrue(multiStr.length > 0, "multi-run result must be non-empty")
    t.expectTrue(multiStr.string.contains("私"), "first base must be present")
    t.expectTrue(multiStr.string.contains("学校"), "second base must be present")

    // Find the location of each base and verify the ruby annotation is set there.
    let nsString = multiStr.string as NSString
    let loc1 = nsString.range(of: "私").location
    let loc2 = nsString.range(of: "学校").location
    t.expectTrue(loc1 != NSNotFound, "base '私' location must be found")
    t.expectTrue(loc2 != NSNotFound, "base '学校' location must be found")

    var r1 = NSRange(); let a1 = multiStr.attribute(
        kCTRubyAnnotationAttributeName as NSAttributedString.Key, at: loc1, effectiveRange: &r1)
    var r2 = NSRange(); let a2 = multiStr.attribute(
        kCTRubyAnnotationAttributeName as NSAttributedString.Key, at: loc2, effectiveRange: &r2)
    t.expectTrue(a1 != nil, "ruby annotation must be set on '私'")
    t.expectTrue(a2 != nil, "ruby annotation must be set on '学校'")

    // ------------------------------------------------------------------
    // 5. Multiple readings: joined by '／', capped at style.maxReadings (default 3).
    //    Read the actual ruby text back out of the CTRubyAnnotation.
    // ------------------------------------------------------------------
    func rubyText(_ s: NSAttributedString, at loc: Int) -> String? {
        guard let attr = s.attribute(kCTRubyAnnotationAttributeName as NSAttributedString.Key,
                                     at: loc, effectiveRange: nil) else { return nil }
        let annotation = attr as! CTRubyAnnotation
        return CTRubyAnnotationGetTextForPosition(annotation, .before) as String?
    }

    // Single reading → no separator.
    let single = builder.build([RubyRun(base: "海月", ruby: "くらげ")])
    t.expectEqual(rubyText(single, at: 0), "くらげ")

    // Four readings, default cap 3 → only the first three shown, '／'-joined.
    let many = builder.build([RubyRun(base: "山茶花", ruby: "さざんか",
                                      alternatives: ["さんざか", "さんさか", "さんちゃか"])])
    t.expectEqual(rubyText(many, at: 0), "さざんか／さんざか／さんさか")

    // A larger cap shows more; a cap of 1 collapses to the primary only.
    let wide = builder.build([RubyRun(base: "角", ruby: "かど", alternatives: ["つの", "すみ"])],
                             style: RubyStyle(maxReadings: 1))
    t.expectEqual(rubyText(wide, at: 0), "かど")
}
