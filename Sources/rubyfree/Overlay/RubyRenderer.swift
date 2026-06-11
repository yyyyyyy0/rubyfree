import AppKit
import RubyfreeCore

// MARK: - RubyRenderer

/// A flipped NSView that draws a semi-transparent rounded-rect backdrop and renders
/// a ruby-annotated NSAttributedString on top. NSAttributedString.draw(in:) handles
/// kCTRubyAnnotationAttributeName correctly without manual CTLine calls.
///
/// Sizing:
///   - `fittingSizeForAttributed` reports the rectangle the caller should give the
///     panel: text.size() + horizontal padding + vertical padding + ruby headroom.
///   - Ruby headroom (`vPadTop`) is derived from `RubyStyle` so a large font size
///     (e.g. 32 pt) does not clip the furigana glyphs at the top edge of the chip.
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
    /// Extra safety margin added on top of the computed ruby height to account for
    /// sub-pixel rounding and ensure glyphs never clip at the chip's top edge.
    private static let vPadTopMargin: CGFloat = 4
    /// Corner radius for the backdrop rectangle.
    private static let cornerRadius: CGFloat = 8

    // MARK: State

    /// Computed headroom above the body text for ruby glyphs. Updated by
    /// `updateStyle(_:)` whenever the active `RubyStyle` changes. Defaults to
    /// the previous fixed value (26 pt) so the renderer is correct before the
    /// coordinator pushes the first style on start-up.
    private var vPadTop: CGFloat = 26

    var attributed: NSAttributedString? {
        didSet { needsDisplay = true }
    }

    /// Push the current ``RubyStyle`` so the renderer can compute the ruby headroom
    /// (`vPadTop`) from first principles: `fontSize × rubyScale + rubyGap + margin`.
    /// Call this whenever the style changes (font size or theme); triggers a redraw.
    func updateStyle(_ style: RubyStyle) {
        let headroom = style.fontSize * style.rubyScale + style.rubyGap + Self.vPadTopMargin
        guard headroom != vPadTop else { return }
        vPadTop = headroom
        needsDisplay = true
    }

    /// Fill colour of the backdrop chip. Defaults mirror `RubyTheme.dark`'s chip so the
    /// renderer looks correct in the brief window before the coordinator pushes the selected
    /// theme's colours on launch via `applyChipColors`. Keep in sync with `RubyTheme.dark`.
    private var chipBackgroundColor: NSColor = NSColor(white: 0.08, alpha: 0.92) {
        didSet { needsDisplay = true }
    }
    /// Stroke (border) colour of the backdrop chip. Mirrors `RubyTheme.dark`'s chip stroke.
    private var chipStrokeColor: NSColor = NSColor(white: 1.0, alpha: 0.18) {
        didSet { needsDisplay = true }
    }

    /// Apply the chip colours from the selected theme. Falls back to the existing colour if
    /// a `CGColor` can't be bridged to `NSColor` (e.g. an unexpected colour space).
    func applyChipColors(background: CGColor, stroke: CGColor) {
        chipBackgroundColor = NSColor(cgColor: background) ?? chipBackgroundColor
        chipStrokeColor = NSColor(cgColor: stroke) ?? chipStrokeColor
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
            height: textSize.height + Self.vPadBottom + vPadTop
        )
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = self.bounds

        // --- Backdrop ---
        // A near-opaque chip so the furigana reads clearly regardless of what is behind it
        // on screen (the captured app may be light or dark). Colours come from the selected
        // theme via `applyChipColors`.
        let path = NSBezierPath(roundedRect: bounds,
                                xRadius: Self.cornerRadius,
                                yRadius: Self.cornerRadius)
        chipBackgroundColor.setFill()
        path.fill()
        chipStrokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        // --- Text ---
        guard let attributed else { return }

        // In a flipped view, (hPad, vPadTop) places the text origin at the top-left
        // of the usable area, leaving vPadTop points of headroom above for ruby glyphs.
        let textOrigin = NSPoint(x: Self.hPad, y: vPadTop)
        let textSize = attributed.size()
        let textRect = NSRect(origin: textOrigin, size: textSize)
        attributed.draw(in: textRect)
    }
}
