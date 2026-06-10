import AppKit
import ApplicationServices
import CoreGraphics
import RubyfreeCore

/// Accessibility-API-based text capture. Retrieves the word/character under the
/// cursor by querying the AX tree of the frontmost application.
///
/// ### Coordinate contract
/// `captureText(at:)` receives a point in **AppKit global coordinates**
/// (bottom-left origin, y-up), which is the native format of `NSEvent.mouseLocation`.
/// Internally the implementation converts to **AX top-left coordinates** before
/// calling `AXUIElementCopyElementAtPosition` and the parameterised attribute APIs,
/// then converts returned bounds back to AppKit before returning.
///
/// ### Thread-safety
/// `AXUIElement` is not `Sendable`.  All element handles are created, used, and
/// released inside a single `captureText` call, never stored as properties, and
/// never allowed to cross the actor boundary.  The only value that leaves the actor
/// is the fully-`Sendable` `CapturedText`.
public actor AXTextCapture: TextCapturing {

    private let converter = CoordinateConverter()
    /// Short per-call AX messaging timeout (seconds).  Keeps the hover latency
    /// budget under control when the target app is unresponsive.
    private let axTimeout: Float = 0.2

    public init() {}

    // MARK: - TextCapturing

    public func captureText(at point: CGPoint) async -> CapturedText? {
        // ── 1. Fetch screen height on the MainActor ───────────────────────
        let globalHeight: CGFloat = await MainActor.run {
            // Use the full virtual-desktop height (union of all screens) so that
            // conversion is consistent on multi-monitor setups.  Fall back to the
            // main screen height if screens list is empty (unlikely but defensive).
            let screens = NSScreen.screens
            if screens.isEmpty {
                return NSScreen.main?.frame.height ?? 800
            }
            return screens.reduce(CGRect.zero) { $0.union($1.frame) }.height
        }

        // ── 2. Convert AppKit bottom-left → AX top-left ───────────────────
        // axToAppKit performs the symmetric flip:  y' = globalHeight - y
        // So appKit→AX uses the same formula (the transform is its own inverse).
        let axPoint = CGPoint(x: point.x, y: globalHeight - point.y)

        // ── 3. Locate the AX element under the cursor ─────────────────────
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, axTimeout)

        var rawElement: AXUIElement?
        let elementErr = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(axPoint.x),
            Float(axPoint.y),
            &rawElement
        )
        guard elementErr == .success, let element = rawElement else { return nil }

        // Apply per-element timeout as well (the element may be in a different process).
        AXUIElementSetMessagingTimeout(element, axTimeout)

        // ── 4. Extract text ───────────────────────────────────────────────
        return extractText(from: element, axPoint: axPoint, globalHeight: globalHeight)
    }

    // MARK: - Private helpers

    /// Tries the full parameterised-attribute path first, then falls back to
    /// whole-value attributes for elements that do not support range queries.
    private func extractText(
        from element: AXUIElement,
        axPoint: CGPoint,
        globalHeight: CGFloat
    ) -> CapturedText? {
        // Primary path: RangeForPosition → StringForRange + BoundsForRange
        if let result = extractViaRangeAttributes(
            from: element, axPoint: axPoint, globalHeight: globalHeight
        ) {
            return result
        }

        // Fallback A: kAXSelectedTextAttribute (non-nil when the user has a selection)
        if let result = extractViaAttribute(
            "AXSelectedText", from: element,
            approximatePoint: axPoint, globalHeight: globalHeight
        ) {
            return result
        }

        // Fallback B: kAXValueAttribute (whole field value — common in text fields)
        if let result = extractViaAttribute(
            "AXValue", from: element,
            approximatePoint: axPoint, globalHeight: globalHeight
        ) {
            return result
        }

        return nil
    }

    /// Parameterised-attribute path:
    ///   AXRangeForPosition(axPoint) → CFRange
    ///   AXStringForRange(range)     → String
    ///   AXBoundsForRange(range)     → CGRect (AX top-left)
    private func extractViaRangeAttributes(
        from element: AXUIElement,
        axPoint: CGPoint,
        globalHeight: CGFloat
    ) -> CapturedText? {
        // Step 4a: encode the AX point as an AXValue and ask for the range.
        var mutablePoint = axPoint
        guard let pointValue = AXValueCreate(.cgPoint, &mutablePoint) else { return nil }

        var rawRange: CFTypeRef?
        let rangeErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXRangeForPosition" as CFString,
            pointValue,
            &rawRange
        )
        guard rangeErr == .success, let rangeValue = rawRange else { return nil }
        // The returned value is an AXValue wrapping a CFRange.
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange),
              cfRange.length > 0 else { return nil }

        // Step 4b: encode the CFRange and fetch the string.
        guard let rangeAXValue = AXValueCreate(.cfRange, &cfRange) else { return nil }

        var rawString: CFTypeRef?
        let stringErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXStringForRange" as CFString,
            rangeAXValue,
            &rawString
        )
        guard stringErr == .success,
              let cfString = rawString,
              CFGetTypeID(cfString) == CFStringGetTypeID() else { return nil }
        let text = cfString as! String
        guard !text.isEmpty else { return nil }

        // Step 4c: fetch the bounding rect (AX top-left coords).
        var rawBounds: CFTypeRef?
        let boundsErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXBoundsForRange" as CFString,
            rangeAXValue,
            &rawBounds
        )

        let appKitRect: CGRect
        if boundsErr == .success,
           let boundsValue = rawBounds {
            var axRect = CGRect.zero
            if AXValueGetValue(boundsValue as! AXValue, .cgRect, &axRect) {
                // Convert AX top-left rect → AppKit bottom-left rect.
                appKitRect = converter.axRectToAppKit(axRect, globalHeight: globalHeight)
            } else {
                appKitRect = fallbackRect(for: axPoint, globalHeight: globalHeight)
            }
        } else {
            appKitRect = fallbackRect(for: axPoint, globalHeight: globalHeight)
        }

        return CapturedText(rawText: text, screenRect: appKitRect, source: .accessibility)
    }

    /// Simple attribute fallback for `AXSelectedText` / `AXValue`.
    /// Bounds are approximated from the element's `AXFrame` if available.
    private func extractViaAttribute(
        _ attribute: String,
        from element: AXUIElement,
        approximatePoint axPoint: CGPoint,
        globalHeight: CGFloat
    ) -> CapturedText? {
        var rawValue: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &rawValue
        )
        guard err == .success,
              let cfValue = rawValue,
              CFGetTypeID(cfValue) == CFStringGetTypeID() else { return nil }
        let text = cfValue as! String
        guard !text.isEmpty else { return nil }

        // Try to read the element's frame for a proper rect.
        let appKitRect = elementAppKitFrame(of: element, globalHeight: globalHeight)
            ?? fallbackRect(for: axPoint, globalHeight: globalHeight)

        return CapturedText(rawText: text, screenRect: appKitRect, source: .accessibility)
    }

    /// Reads `AXFrame` from the element and converts to AppKit coordinates.
    private func elementAppKitFrame(
        of element: AXUIElement,
        globalHeight: CGFloat
    ) -> CGRect? {
        var rawFrame: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            element,
            "AXFrame" as CFString,
            &rawFrame
        )
        guard err == .success, let frameValue = rawFrame else { return nil }
        var axRect = CGRect.zero
        guard AXValueGetValue(frameValue as! AXValue, .cgRect, &axRect) else { return nil }
        return converter.axRectToAppKit(axRect, globalHeight: globalHeight)
    }

    /// When no bounds are available, return a small rect centred on the cursor
    /// (already in AppKit coordinates).
    private func fallbackRect(for axPoint: CGPoint, globalHeight: CGFloat) -> CGRect {
        let appKitPoint = converter.axToAppKit(axPoint, globalHeight: globalHeight)
        let side: CGFloat = 20
        return CGRect(
            x: appKitPoint.x - side / 2,
            y: appKitPoint.y - side / 2,
            width: side,
            height: side
        )
    }
}
