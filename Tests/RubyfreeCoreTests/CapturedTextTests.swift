import CoreGraphics
import RubyfreeCore
import TinyTest

func testCapturedTextSanitize(_ t: TinyTest) {
    let rect = CGRect(x: 0, y: 0, width: 10, height: 10)

    // strips zero-width (200B) + bidi override (202E), collapses whitespace, trims
    let c = CapturedText(rawText: "  漢\u{200B}字\u{202E}  検定\n", screenRect: rect, source: .accessibility)
    t.expectEqual(c?.text, "漢字 検定")

    // all-removable content → nil
    t.expectTrue(
        CapturedText(rawText: "\u{200B}\u{FEFF}\u{0007}", screenRect: rect, source: .accessibility) == nil,
        "all-stripped text should be nil"
    )

    // invalid rect (NaN) → nil
    t.expectTrue(
        CapturedText(rawText: "あ", screenRect: CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), source: .accessibility) == nil,
        "NaN rect should be nil"
    )

    // length clamp (DoS guard)
    let long = String(repeating: "字", count: 500)
    t.expectEqual(
        CapturedText(rawText: long, screenRect: rect, source: .accessibility)?.text.count,
        CapturedText.maxLength
    )

    // source confidence preserved
    let ocr = CapturedText(rawText: "本", screenRect: rect, source: .ocr(confidence: 0.9))
    t.expectEqual(ocr?.source, .ocr(confidence: 0.9))
}
