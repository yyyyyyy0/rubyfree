import AppKit
import ApplicationServices
import RubyfreeCore

/// Queries and requests the macOS TCC permissions rubyfree requires.
///
/// All AX / CGS API calls are synchronous; `NSWorkspace` requires `@MainActor` isolation,
/// so `openAccessibilitySettings()` dispatches to the main actor from inside an
/// unstructured `Task` — the protocol is `Sendable` (non-MainActor), so we cannot mark
/// the method `@MainActor` directly.
public struct AXPermissionChecker: PermissionChecking {

    public init() {}

    // MARK: - PermissionChecking

    /// Returns a snapshot of the current Accessibility and Screen Recording grants.
    public func current() -> PermissionStatus {
        PermissionStatus(
            accessibility: AXIsProcessTrusted(),
            screenRecording: CGPreflightScreenCaptureAccess()
        )
    }

    /// Shows the Accessibility permission dialog if not yet granted.
    ///
    /// Uses the string literal `"AXTrustedCheckOptionPrompt"` instead of the SDK constant
    /// `kAXTrustedCheckOptionPrompt` to avoid a Swift 6 concurrency-unsafe global warning
    /// (the constant's value is stable public API and will not change).
    public func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
    }

    /// Prompts for Screen Recording access (call only when the OCR fallback is being
    /// enabled — JIT, per the protocol contract).
    public func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    /// Opens System Settings at the Privacy → Accessibility pane so the user can grant
    /// or review the permission. The `NSWorkspace` API requires `@MainActor` isolation;
    /// because this method is part of a non-`@MainActor` `Sendable` protocol we dispatch
    /// to the main actor via an unstructured `Task`.  The Task's lifetime is intentionally
    /// fire-and-forget: the URL open completes on the system side and no result is needed.
    public func openAccessibilitySettings() {
        // Force-unwrap is safe: the URL string is a hardcoded compile-time literal.
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens System Settings at Privacy → Screen Recording (for the OCR fallback grant).
    public func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
    }
}
