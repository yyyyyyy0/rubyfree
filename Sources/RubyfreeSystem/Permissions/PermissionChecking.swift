import RubyfreeCore

/// Queries and requests the macOS permissions rubyfree uses. Screen Recording is
/// requested lazily (only when the OCR fallback is actually enabled).
public protocol PermissionChecking: Sendable {
    func current() -> PermissionStatus
    /// Prompt for Accessibility (shows the system dialog on first call).
    func requestAccessibility()
    /// Prompt for Screen Recording — call only when OCR is being enabled (JIT).
    func requestScreenRecording()
    /// Open System Settings at the Accessibility pane.
    func openAccessibilitySettings()
}
