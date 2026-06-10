import CoreGraphics

/// Pure, OS-independent coordinate conversion utilities.
///
/// Two coordinate systems are in play on macOS:
///
/// - **AX / HIToolbox**: origin at top-left of the global virtual desktop,
///   y increases downward.  All values are in **points**.
/// - **AppKit / CoreGraphics**: origin at bottom-left of the global virtual
///   desktop, y increases upward.  All values are in **points**.
///
/// Callers must supply the values that normally come from `NSScreen`:
/// - `globalHeight` — total height of the virtual desktop in points (i.e.
///   the `frame.height` of the `NSScreen.screens` union rect, **not** the
///   height of a single screen).
/// - `scale` — the backing-store pixel-to-point ratio (e.g. `2.0` for
///   Retina displays, `1.0` otherwise).
///
/// Keeping OS types out of this struct means the entire conversion logic is
/// fully unit-testable without a display attached.
public struct CoordinateConverter: Sendable {

    public init() {}

    // MARK: - AX ↔ AppKit (point-level, y-flip only)

    /// Converts an AX global point (top-left origin, y-down) to an AppKit
    /// global point (bottom-left origin, y-up).
    ///
    /// - Parameters:
    ///   - point: Input point in AX coordinates (top-left global, points).
    ///   - globalHeight: Height of the virtual desktop in points.
    /// - Returns: Equivalent point in AppKit coordinates (bottom-left global,
    ///   points).
    public func axToAppKit(_ point: CGPoint, globalHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: globalHeight - point.y)
    }

    /// Converts an AX global rect (top-left origin, y-down) to an AppKit
    /// global rect (bottom-left origin, y-up).
    ///
    /// The AX rect's `origin` is its **top-left** corner; the AppKit rect's
    /// `origin` is its **bottom-left** corner.  Both representations use
    /// point units.
    ///
    /// - Parameters:
    ///   - rect: Input rect in AX coordinates (top-left global, points).
    ///   - globalHeight: Height of the virtual desktop in points.
    /// - Returns: Equivalent rect in AppKit coordinates (bottom-left global,
    ///   points).
    public func axRectToAppKit(_ rect: CGRect, globalHeight: CGFloat) -> CGRect {
        // AX origin is the top-left corner; in AppKit the bottom-left corner
        // of the same box sits at `globalHeight - (origin.y + height)`.
        let appKitY = globalHeight - (rect.origin.y + rect.height)
        return CGRect(x: rect.origin.x, y: appKitY,
                      width: rect.width, height: rect.height)
    }

    // MARK: - HiDPI pixel → point

    /// Converts a rect expressed in physical pixels to logical points by
    /// dividing by the display's backing-scale factor.
    ///
    /// - Parameters:
    ///   - rect: Input rect in physical pixels.
    ///   - scale: Backing-store scale (e.g. `2.0` for Retina, `1.0` otherwise).
    /// - Returns: Equivalent rect in logical points.
    public func pixelToPoint(_ rect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x / scale,
            y: rect.origin.y / scale,
            width: rect.width / scale,
            height: rect.height / scale
        )
    }
}
