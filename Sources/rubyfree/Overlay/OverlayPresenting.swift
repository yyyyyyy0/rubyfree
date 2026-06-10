import AppKit

/// Shows / hides the ruby overlay. AppCoordinator (composition root) depends on this
/// abstraction; OverlayWindowController implements it with a transparent, click-through
/// non-activating NSPanel. Main-actor bound because it touches AppKit windows.
@MainActor
protocol OverlayPresenting: AnyObject {
    /// Display `attributed` (ruby-annotated) positioned for a base word at `screenRect`
    /// (AppKit global, bottom-left, points).
    func show(_ attributed: NSAttributedString, at screenRect: CGRect)
    func hide()
}
