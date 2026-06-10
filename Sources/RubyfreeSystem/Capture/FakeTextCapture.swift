import CoreGraphics
import RubyfreeCore

/// Deterministic capture for development / E2E without Accessibility. Enabled via the
/// RUBYFREE_FAKE_CAPTURE environment variable in the composition root, so the whole
/// hover→analyze→compose→overlay pipeline and state machine can be exercised without
/// granting permissions or depending on another app's AX tree.
public struct FakeTextCapture: TextCapturing {
    public let text: String

    public init(text: String = "漢字検定の勉強") {
        self.text = text
    }

    public func captureText(at point: CGPoint) async -> CapturedText? {
        CapturedText(
            rawText: text,
            screenRect: CGRect(x: point.x, y: point.y, width: 120, height: 22),
            source: .accessibility
        )
    }
}
