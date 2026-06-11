import AppKit
import ApplicationServices
import CoreGraphics

/// Detects whether the UI element under a screen point is a secure (password) text field
/// by querying the Accessibility tree.
///
/// ### Coordinate system
/// `isSecureField(at:)` receives a CoreGraphics / AppKit **bottom-left** origin point.
/// `AXUIElementCopyElementAtPosition` expects **top-left** origin (screen coordinates used
/// by HIServices), so we flip the y-axis using the primary screen height.
///
/// ### Judgment policy
/// - `true`  — subrole is `"AXSecureTextField"` (macOS's stable AX constant value).
/// - `false` — element not found, AX not trusted, attribute read failure, or any other
///             error. We always fall back to `false` (non-secure assumption) rather than
///             blocking capture on uncertainty, because:
///             1. Blocking on uncertainty would make hover unusable in AX-denied environments.
///             2. The caller (pipeline) already guards the OCR path separately.
///             If you want fail-closed semantics (suppress on uncertainty), swap the
///             `return false` in the error paths to `return true`.
///
/// ### Thread safety
/// `AXUIElement` is explicitly kept local to each call and is never stored or crossed
/// actor boundaries, satisfying Swift 6 strict concurrency (`AXUIElement` is
/// `CoreFoundation`-based and non-Sendable).
public struct AXSecureFieldDetector: SecureFieldDetecting {

    public init() {}

    // MARK: - SecureFieldDetecting

    public func isSecureField(at point: CGPoint) -> Bool {
        // 1. Flip y: AppKit bottom-left → HIServices top-left.
        //    The flip must pivot on the PRIMARY screen height (the (0,0)-origin menu-bar
        //    screen), NOT NSScreen.main (which tracks the active window and can be a
        //    secondary display). Using the wrong height on a multi-monitor setup would
        //    hit-test the wrong location and could miss a secure field — a privacy hole.
        //    This mirrors the coordinate convention in AXTextCapture / CoordinateConverter.
        let screens = NSScreen.screens
        guard let primary = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first
        else { return false }  // headless / test: cannot convert → treat as non-secure
        let flippedPoint = CGPoint(x: point.x, y: primary.frame.height - point.y)

        // 2. Hit-test the AX tree.
        let systemWide = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?
        let hitResult = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(flippedPoint.x),
            Float(flippedPoint.y),
            &elementRef
        )
        guard hitResult == .success, let element = elementRef else { return false }

        // 3. Read the subrole attribute.
        //    Use string literals instead of kAXSubroleAttribute / kAXSecureTextFieldSubrole
        //    to avoid Swift 6 concurrency-unsafe global variable warnings.
        var subroleValue: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(
            element,
            "AXSubrole" as CFString,  // kAXSubroleAttribute value (stable public API)
            &subroleValue
        )
        guard subroleResult == .success,
              let subrole = subroleValue as? String
        else { return false }

        // 4. "AXSecureTextField" is the value of kAXSecureTextFieldSubrole.
        return subrole == "AXSecureTextField"
    }
}
