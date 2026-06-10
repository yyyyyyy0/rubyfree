/// Where a captured text came from. OCR carries the recognizer confidence so the UI
/// can de-emphasise low-confidence results.
public enum CaptureSource: Equatable, Sendable {
    case accessibility
    case ocr(confidence: Double)
}
