import CoreGraphics

/// Detects whether the element under a point is a secure input (password field), so the
/// pipeline can suppress capture there. This is a hard privacy requirement: never read —
/// via AX or OCR — text the user has chosen to hide.
public protocol SecureFieldDetecting: Sendable {
    func isSecureField(at point: CGPoint) -> Bool
}

/// Always-false detector for environments without AX (tests / Fake mode).
public struct NoSecureFieldDetector: SecureFieldDetecting {
    public init() {}
    public func isSecureField(at point: CGPoint) -> Bool { false }
}
