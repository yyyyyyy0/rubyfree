import Foundation
import CoreFoundation

/// Pure word-boundary lookup, shared by the Accessibility capture path.
///
/// The AX API `AXRangeForPosition` yields the *character* under the cursor (a length-1
/// range), but furigana is only meaningful per *word*. This helper expands a character
/// offset to the surrounding word using the same `ja_JP` word-boundary tokenizer that
/// `StandardAnalyzer` uses, so segmentation is consistent between the two.
///
/// Offsets are **UTF-16 code-unit** indices (CFRange / AX convention), not Swift
/// `String.Index`. OS-independent and fully unit-testable (CoreFoundation only).
public enum WordBoundary {

    /// The UTF-16 range of the word containing `utf16Index` in `text`.
    ///
    /// - Returns: A `CFRange` (UTF-16 location/length), or `nil` if the index is out of
    ///   bounds or no token covers it.
    public static func wordRange(in text: String, utf16Index: Int) -> CFRange? {
        let cf = text as CFString
        let length = CFStringGetLength(cf)
        guard utf16Index >= 0, utf16Index < length else { return nil }

        guard let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            cf,
            CFRangeMake(0, length),
            kCFStringTokenizerUnitWordBoundary,
            Locale(identifier: "ja_JP") as CFLocale
        ) else { return nil }

        let type = CFStringTokenizerGoToTokenAtIndex(tokenizer, CFIndex(utf16Index))
        guard type != [] else { return nil }

        let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
        guard range.location != kCFNotFound, range.length > 0 else { return nil }
        return range
    }
}
