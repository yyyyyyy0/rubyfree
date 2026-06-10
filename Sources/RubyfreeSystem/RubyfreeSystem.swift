// RubyfreeSystem — OS-boundary wrappers.
//
// Translates between the OS (Accessibility, ScreenCaptureKit, Vision, global input)
// and Core value types. Non-Sendable OS handles (e.g. AXUIElement) must be created
// and consumed entirely within this layer; only Sendable Core value types cross out.
//
// Real types (AXTextCapture actor, OCRTextCapture, TextCaptureStrategy,
// GlobalMouseMonitor, PermissionChecker, SecureFieldDetector) land in M3/M5.

import RubyfreeCore

public enum RubyfreeSystem {
    /// Module version marker. Replaced by real types in M3.
    public static let version = RubyfreeCore.version
}
