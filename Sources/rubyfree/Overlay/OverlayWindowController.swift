import AppKit
import RubyfreeCore

// MARK: - OverlayWindowController

/// A transparent, click-through, always-on-top NSPanel that renders ruby-annotated
/// text above a base-word rectangle supplied by the caller.
///
/// Panel configuration:
///   - styleMask: [.nonactivatingPanel, .borderless]  — no title bar, never steals focus
///   - level:     .statusBar                          — floats above normal windows
///   - opaque / background: false / .clear            — pixel-perfect transparency
///   - hasShadow: false                               — avoids a square shadow around
///                                                      the transparent panel
///   - ignoresMouseEvents: true                       — full click-through
///   - collectionBehavior: [.canJoinAllSpaces,
///                          .fullScreenAuxiliary,
///                          .stationary]              — visible on all Spaces / FS apps
///   - hidesOnDeactivate: false                       — stays up when user switches apps
///
/// Positioning (OverlayPresenting.show):
///   screenRect is an AppKit global rect (bottom-left origin, points) for the base word.
///   The panel is sized to fittingSizeForAttributed and placed so that:
///     • The text baseline area sits at screenRect.maxY (base word top edge).
///     • Ruby glyphs extend above that edge into the extra vPadTop headroom.
///   This means the panel's bottom edge aligns with the top of the base word rectangle.
///
/// Multi-display:
///   The screen that contains screenRect.origin is used for coordinate clamping.
///   Falls back to NSScreen.main when no matching screen is found.
@MainActor
final class OverlayWindowController: OverlayPresenting {

    // MARK: Fade animation

    private static let fadeInDuration:  TimeInterval = 0.12
    private static let fadeOutDuration: TimeInterval = 0.10

    /// Vertical gap between the top of the hovered word and the bottom of the chip, so a
    /// large/zoomed mouse cursor on the word does not cover the furigana.
    private static let cursorClearanceGap: CGFloat = 10

    // MARK: Stored properties

    private let panel: NSPanel
    private let renderer: RubyRenderer

    // MARK: Init

    init() {
        // Build the transparent panel.
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0

        let renderer = RubyRenderer()
        panel.contentView = renderer

        self.panel = panel
        self.renderer = renderer
    }

    // MARK: OverlayPresenting

    func show(_ attributed: NSAttributedString, at screenRect: CGRect) {
        // 1. Give the renderer the new attributed string.
        renderer.attributed = attributed

        // 2. Compute the required panel size.
        let size = renderer.fittingSizeForAttributed

        // 3. Determine which screen to use.
        //    Prefer the screen whose frame contains the origin of screenRect.
        let targetScreen = NSScreen.screens.first {
            NSMouseInRect(screenRect.origin, $0.frame, false)
        } ?? NSScreen.main

        // 4. Build the panel frame.
        //    Place the panel so its bottom edge aligns with the top of screenRect.
        //    Horizontally centre over screenRect with mild centering offset.
        let panelX = screenRect.midX - size.width / 2
        // Lift the chip a few points above the word so a large/zoomed cursor sitting on
        // the word doesn't occlude it. AppKit Y grows upward.
        let panelY = screenRect.maxY + Self.cursorClearanceGap

        var panelFrame = NSRect(
            x: panelX,
            y: panelY,
            width: size.width,
            height: size.height
        )

        // 5. Clamp to the visible area of the target screen so the panel never
        //    escapes off-screen (best-effort; panel may shrink near screen edges).
        if let screen = targetScreen {
            let visibleFrame = screen.visibleFrame
            panelFrame.origin.x = max(visibleFrame.minX,
                                      min(panelFrame.origin.x,
                                          visibleFrame.maxX - panelFrame.width))
            panelFrame.origin.y = max(visibleFrame.minY,
                                      min(panelFrame.origin.y,
                                          visibleFrame.maxY - panelFrame.height))
        }

        // 6. Position and show the panel without stealing key focus.
        panel.setFrame(panelFrame, display: false)
        panel.orderFrontRegardless()

        // 7. Fade in.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeOutDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            // NSAnimationContext's completionHandler is nonisolated; re-enter
            // MainActor to call the @MainActor-isolated orderOut(_:).
            // The animation framework guarantees this callback fires on the main
            // thread, so assumeIsolated is safe here.
            MainActor.assumeIsolated {
                panel?.orderOut(nil)
            }
        })
    }

    func applyTheme(_ theme: RubyTheme) {
        renderer.applyChipColors(
            background: theme.chipBackgroundColor,
            stroke: theme.chipStrokeColor
        )
    }
}
