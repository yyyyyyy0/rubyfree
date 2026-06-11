import Foundation
import CoreFoundation
import RubyfreeCore
import TinyTest

func testWordBoundary(_ t: TinyTest) {
    // Helper: substring for a CFRange (UTF-16 offsets) within `text`.
    func sub(_ text: String, _ r: CFRange) -> String {
        let u = Array(text.utf16)
        guard r.location >= 0, r.length > 0, r.location + r.length <= u.count else { return "" }
        return String(decoding: u[r.location ..< (r.location + r.length)].flatMap { [$0] },
                      as: UTF16.self)
    }

    let text = "今日は良い天気ですね"

    // Index on the first kanji of "今日" → whole word "今日".
    if let r = WordBoundary.wordRange(in: text, utf16Index: 0) {
        t.expectEqual(sub(text, r), "今日")
    } else {
        t.expectTrue(false, "expected a word range at index 0")
    }

    // Index on the second code unit of "今日" still resolves to "今日".
    if let r = WordBoundary.wordRange(in: text, utf16Index: 1) {
        t.expectEqual(sub(text, r), "今日")
    } else {
        t.expectTrue(false, "expected a word range at index 1")
    }

    // Index on "良" (offset 3) → "良い" (kanji + okurigana kept together).
    if let r = WordBoundary.wordRange(in: text, utf16Index: 3) {
        t.expectEqual(sub(text, r), "良い")
    } else {
        t.expectTrue(false, "expected a word range at index 3")
    }

    // The returned range always contains the queried index.
    if let r = WordBoundary.wordRange(in: text, utf16Index: 5) {
        t.expectTrue(r.location <= 5 && 5 < r.location + r.length,
                     "returned range must contain the queried index")
    }

    // Out-of-bounds indices return nil.
    t.expectTrue(WordBoundary.wordRange(in: text, utf16Index: -1) == nil, "negative index → nil")
    t.expectTrue(WordBoundary.wordRange(in: text, utf16Index: 999) == nil, "index past end → nil")

    // Empty string returns nil for any index.
    t.expectTrue(WordBoundary.wordRange(in: "", utf16Index: 0) == nil, "empty text → nil")
}
