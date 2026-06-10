import CoreGraphics
import RubyfreeCore

/// Captures the text under a screen point. Implementations live in the System layer and
/// must keep non-Sendable OS handles (e.g. AXUIElement) internal — only the Sendable
/// `CapturedText` value crosses out.
public protocol TextCapturing: Sendable {
    func captureText(at point: CGPoint) async -> CapturedText?
}

/// AX-first, OCR-fallback strategy. `fallback` is nil when Screen Recording is not
/// granted (OCR disabled), so capture degrades to AX-only.
public struct TextCaptureStrategy: TextCapturing {
    public let primary: any TextCapturing
    public let fallback: (any TextCapturing)?

    public init(primary: any TextCapturing, fallback: (any TextCapturing)? = nil) {
        self.primary = primary
        self.fallback = fallback
    }

    public func captureText(at point: CGPoint) async -> CapturedText? {
        if let hit = await primary.captureText(at: point) { return hit }
        return await fallback?.captureText(at: point)
    }
}
