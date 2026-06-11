import AppKit

// MARK: - RubyRenderer

/// A flipped NSView that draws a semi-transparent rounded-rect backdrop and renders
/// a ruby-annotated NSAttributedString on top. NSAttributedString.draw(in:) handles
/// kCTRubyAnnotationAttributeName correctly without manual CTLine calls.
///
/// Sizing:
///   - `fittingSizeForAttributed` reports the rectangle the caller should give the
///     panel: text.size() + horizontal padding + vertical padding + ruby headroom.
///
/// Appearance:
///   - Background tracks the effective appearance (dark / light) through
///     NSColor.windowBackgroundColor, so it works in both modes without explicit
///     monitoring.
@MainActor
final class RubyRenderer: NSView {

    // MARK: Layout constants

    /// Horizontal inset inside the panel on each side.
    private static let hPad: CGFloat = 12
    /// Padding below the text baseline to the panel bottom.
    private static let vPadBottom: CGFloat = 8
    /// Padding above the text top to the panel top.  Extra space lets ruby glyphs
    /// (plus the lifted ruby gap) sit fully inside the panel.
    private static let vPadTop: CGFloat = 26
    /// Corner radius for the backdrop rectangle.
    private static let cornerRadius: CGFloat = 8

    // MARK: State

    var attributed: NSAttributedString? {
        didSet { needsDisplay = true }
    }

    // MARK: Coordinate system

    /// Use a flipped coordinate system so (0,0) is the top-left corner, which makes
    /// NSAttributedString.draw(at:) place the text at the top-left of the content
    /// area with ruby glyphs extending upward — matching the reserved vPadTop space.
    override var isFlipped: Bool { true }

    // MARK: Fitting size

    /// Preferred panel content size for the current `attributed` value.
    /// Returns a minimal non-zero size when `attributed` is nil.
    var fittingSizeForAttributed: NSSize {
        guard let attributed else {
            return NSSize(width: 60, height: 30)
        }
        let textSize = attributed.size()
        return NSSize(
            width: textSize.width + Self.hPad * 2,
            height: textSize.height + Self.vPadBottom + Self.vPadTop
        )
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds

        // --- Backdrop ---
        // A dark, near-opaque chip so the bright furigana reads clearly regardless of
        // what is behind it on screen (the captured app may be light or dark).
        let path = NSBezierPath(roundedRect: bounds,
                                xRadius: Self.cornerRadius,
                                yRadius: Self.cornerRadius)
        NSColor(white: 0.08, alpha: 0.92).setFill()
        path.fill()
        NSColor(white: 1.0, alpha: 0.18).setStroke()
        path.lineWidth = 1
        path.stroke()

        // --- Text ---
        guard let attributed else { return }

        // In a flipped view, (hPad, vPadTop) places the text origin at the top-left
        // of the usable area, leaving vPadTop points of headroom above for ruby glyphs.
        let textOrigin = NSPoint(x: Self.hPad, y: Self.vPadTop)
        let textSize = attributed.size()
        let textRect = NSRect(origin: textOrigin, size: textSize)
        attributed.draw(in: textRect)
    }
}
