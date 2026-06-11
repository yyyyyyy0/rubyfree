import AppKit
import RubyfreeCore

/// Shows / hides the ruby overlay. AppCoordinator (composition root) depends on this
/// abstraction; OverlayWindowController implements it with a transparent, click-through
/// non-activating NSPanel. Main-actor bound because it touches AppKit windows.
@MainActor
protocol OverlayPresenting: AnyObject {
    /// Display `attributed` (ruby-annotated) positioned for a base word at `screenRect`
    /// (AppKit global, bottom-left, points).
    func show(_ attributed: NSAttributedString, at screenRect: CGRect)
    func hide()
    /// Apply the selected theme's chip colours to the overlay. Text colours are baked into
    /// the attributed string by the caller; this carries only the chip (background/stroke).
    func applyTheme(_ theme: RubyTheme)
    /// Push the current ``RubyStyle`` so the renderer can derive the correct ruby headroom
    /// from `fontSize × rubyScale + rubyGap`. Must be called whenever the style changes.
    func updateStyle(_ style: RubyStyle)
}
