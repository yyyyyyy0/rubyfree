// RubyfreeCore — pure domain logic.
//
// LAYER RULE: this target must not import AppKit, ScreenCaptureKit, Vision, or any
// OS-boundary framework. It deals only in value types and CoreGraphics primitives
// (CGPoint / CGRect). The boundary is enforced by SwiftPM target separation.
//
// Real domain types (JapaneseAnalyzing, HoverReducer, AppState, CoordinateConverter,
// CapturedText, RubyComposer, RubyAttributedBuilder, …) land in M2.

public enum RubyfreeCore {
    /// Module version marker. Replaced by real types in M2.
    public static let version = "0.0.1"
}
