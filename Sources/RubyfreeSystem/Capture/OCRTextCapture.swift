import CoreGraphics
import RubyfreeCore

/// OCR-based `TextCapturing`: the fallback used when AX cannot localize the word under
/// the cursor (NSTextView, WebKit, PDFs, images of text). Clips a small region around the
/// cursor, recognizes it with Vision, and returns the single word under the cursor with
/// its on-screen rect.
///
/// A stateless `struct` whose `captureText` is `nonisolated async`: the ~160ms Vision
/// call runs on the global executor (off the main actor), and only the `Sendable`
/// `CapturedText` crosses back out.
public struct OCRTextCapture: TextCapturing {

    private let region = ScreenRegionCapture()
    private let recognizer: VisionTextRecognizer

    /// Logical-point size of the region clipped around the cursor. Kept above the size at
    /// which Vision's detector becomes unstable, while small enough to stay fast.
    private let regionSize = CGSize(width: 280, height: 140)

    /// - Parameter dictionary: gates okurigana expansion of recognized kanji runs (宛 → 宛も).
    ///   `nil` disables expansion.
    public init(dictionary: ReadingDictionary? = nil) {
        self.recognizer = VisionTextRecognizer(dictionary: dictionary)
    }

    /// Pay Vision's one-time model load at startup.
    public func prewarm() async { await recognizer.prewarm() }

    public func captureText(at point: CGPoint) async -> CapturedText? {
        guard let shot = await region.capture(around: point, size: regionSize) else { return nil }

        // Cursor position inside the image (pixels, upper-left origin).
        let cursorImage = CGPoint(
            x: (point.x - shot.regionAppKit.minX) * shot.scale,
            y: (shot.regionAppKit.maxY - point.y) * shot.scale
        )

        guard let word = await recognizer.wordNear(cursorImage, in: shot.image) else {
            DebugLog.log("ocr: no word near cursor")
            return nil
        }

        // Word box (image px, upper-left) → region-local points → AppKit global (bottom-left).
        let boxPt = CGRect(
            x: word.boxInImage.minX / shot.scale,
            y: word.boxInImage.minY / shot.scale,
            width: word.boxInImage.width / shot.scale,
            height: word.boxInImage.height / shot.scale
        )
        let rect = CGRect(
            x: shot.regionAppKit.minX + boxPt.minX,
            y: shot.regionAppKit.maxY - (boxPt.minY + boxPt.height),
            width: boxPt.width,
            height: boxPt.height
        )
        DebugLog.log("ocr: word len=\(word.text.count) conf=\(String(format: "%.2f", word.confidence)) rect=(\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height)))")

        return CapturedText(rawText: word.text, screenRect: rect, source: .ocr(confidence: word.confidence))
    }
}
