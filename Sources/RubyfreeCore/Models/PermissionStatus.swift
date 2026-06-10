/// Snapshot of the macOS permissions rubyfree cares about. Accessibility is required;
/// Screen Recording is optional (only needed for the OCR fallback).
public struct PermissionStatus: Equatable, Sendable {
    public let accessibility: Bool
    public let screenRecording: Bool

    public init(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }

    /// Can run with AX-only capture (the minimum required to function).
    public var canRunAXOnly: Bool { accessibility }

    /// Can run the OCR fallback.
    public var canRunOCR: Bool { screenRecording }
}
