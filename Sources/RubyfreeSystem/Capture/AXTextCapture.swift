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
        // ── 1. Fetch the flip reference height on the MainActor ───────────
        // The Cocoa↔CG/AX y-flip pivots on the *primary* screen's top edge — the
        // screen whose frame origin is (0,0), which carries the menu bar — NOT the
        // union of all screens. Using the union height injects a constant vertical
        // offset equal to however far a secondary display overhangs above/below the
        // primary, which silently misplaces every hit-test on multi-display setups.
        let globalHeight: CGFloat = await MainActor.run {
            let screens = NSScreen.screens
            let primary = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first
            return primary?.frame.height ?? NSScreen.main?.frame.height ?? 800
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
        DebugLog.log("capture: appkit=(\(Int(point.x)),\(Int(point.y))) ax=(\(Int(axPoint.x)),\(Int(axPoint.y))) H=\(Int(globalHeight)) elementErr=\(elementErr.rawValue)")
        guard elementErr == .success, let element = rawElement else { return nil }

        if DebugLog.enabled {
            var roleRaw: CFTypeRef?
            AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRaw)
            let role = (roleRaw as? String) ?? "?"
            var attrs: CFArray?
            AXUIElementCopyAttributeNames(element, &attrs)
            var params: CFArray?
            AXUIElementCopyParameterizedAttributeNames(element, &params)
            let attrList = ((attrs as? [String]) ?? []).joined(separator: ",")
            let paramList = ((params as? [String]) ?? []).joined(separator: ",")
            DebugLog.log("capture: role=\(role)\n  attrs=[\(attrList)]\n  params=[\(paramList)]")
        }

        // Apply per-element timeout as well (the element may be in a different process).
        AXUIElementSetMessagingTimeout(element, axTimeout)

        // ── 4. Extract text ───────────────────────────────────────────────
        let result = extractText(from: element, axPoint: axPoint, globalHeight: globalHeight)
        DebugLog.log("capture: result=\(result == nil ? "nil" : "len=\(result!.text.count) source=\(result!.source)")")
        return result
    }

    // MARK: - Private helpers

    /// Upper bound on a plausible `AXRangeForPosition` length. The attribute is meant to
    /// return the single character under the point (length 1); some elements return a
    /// word. Anything larger (notably the `~Int64.max` garbage some controls emit) is a
    /// bug and is rejected so we never capture a whole line/document.
    private static let maxCursorRangeLength = 64
    /// Half-width (in UTF-16 units) of the text window fetched around the cursor for
    /// word-boundary expansion.
    private static let wordWindowRadius = 40

    /// Extracts the *word* under the cursor using only the parameterised range APIs that
    /// reliably localise a position:
    ///   AXRangeForPosition(point) → cursor index → word range (CFStringTokenizer)
    ///   → AXBoundsForRange(word)  → screen rect
    ///
    /// Returns `nil` for elements that do not support position→index/bounds mapping
    /// (e.g. NSTextView/`AXTextArea`, WebKit text). Those are handled by the OCR
    /// fallback in the capture orchestrator — there is deliberately no whole-`AXValue`
    /// fallback here, which would dump an entire line/field instead of a single word.
    private func extractText(
        from element: AXUIElement,
        axPoint: CGPoint,
        globalHeight: CGFloat
    ) -> CapturedText? {
        // 1. Cursor character index from the hovered point.
        guard let cursor = cursorRange(in: element, axPoint: axPoint) else { return nil }

        // 2. Expand the cursor index to the surrounding word.
        let wordRange = expandToWord(in: element, cursor: cursor)

        // 3. Word text (local slice of the fetched window when available, else AX).
        guard let text = string(for: wordRange, in: element), !text.isEmpty else { return nil }

        // 4. Screen rect for the word — required (no rect ⇒ cannot place the overlay).
        guard let appKitRect = bounds(for: wordRange, in: element, globalHeight: globalHeight) else {
            DebugLog.log("ax: no bounds for word range → defer to OCR")
            return nil
        }

        return CapturedText(rawText: text, screenRect: appKitRect, source: .accessibility)
    }

    /// `AXRangeForPosition` → validated single-character `CFRange`, or `nil`.
    private func cursorRange(in element: AXUIElement, axPoint: CGPoint) -> CFRange? {
        var mutablePoint = axPoint
        guard let pointValue = AXValueCreate(.cgPoint, &mutablePoint) else { return nil }

        var raw: CFTypeRef?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element, "AXRangeForPosition" as CFString, pointValue, &raw
        )
        DebugLog.log("ax: AXRangeForPosition err=\(err.rawValue)")
        guard err == .success, let value = raw else { return nil }

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }

        // Reject implausible ranges (negative, zero, or the ~Int64.max garbage).
        guard range.location >= 0,
              range.length > 0,
              range.length <= Self.maxCursorRangeLength else {
            DebugLog.log("ax: reject range loc=\(range.location) len=\(range.length)")
            return nil
        }
        return range
    }

    /// Expands a cursor `CFRange` to the word that contains it, using a bounded text
    /// window fetched via `AXStringForRange` and the shared `ja_JP` tokenizer. Falls back
    /// to the original cursor range if the window or tokenizer is unavailable.
    private func expandToWord(in element: AXUIElement, cursor: CFRange) -> CFRange {
        let winLoc = max(0, cursor.location - Self.wordWindowRadius)
        let winLen = (cursor.location - winLoc) + Self.wordWindowRadius
        let windowRange = CFRange(location: winLoc, length: winLen)

        guard let window = string(for: windowRange, in: element), !window.isEmpty else {
            return cursor
        }
        let indexInWindow = cursor.location - winLoc
        guard let local = WordBoundary.wordRange(in: window, utf16Index: indexInWindow) else {
            return cursor
        }
        let absolute = CFRange(location: winLoc + local.location, length: local.length)
        DebugLog.log("ax: word range loc=\(absolute.location) len=\(absolute.length)")
        return absolute
    }

    /// `AXStringForRange(range)` → `String`.
    private func string(for range: CFRange, in element: AXUIElement) -> String? {
        var mutable = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutable) else { return nil }
        var raw: CFTypeRef?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element, "AXStringForRange" as CFString, rangeValue, &raw
        )
        guard err == .success, let cf = raw, CFGetTypeID(cf) == CFStringGetTypeID() else { return nil }
        return (cf as! String)
    }

    /// `AXBoundsForRange(range)` → AppKit rect (converted from AX top-left coords).
    private func bounds(for range: CFRange, in element: AXUIElement, globalHeight: CGFloat) -> CGRect? {
        var mutable = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutable) else { return nil }
        var raw: CFTypeRef?
        let err = AXUIElementCopyParameterizedAttributeValue(
            element, "AXBoundsForRange" as CFString, rangeValue, &raw
        )
        guard err == .success, let value = raw else { return nil }
        var axRect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &axRect),
              axRect.width > 0, axRect.height > 0 else { return nil }
        return converter.axRectToAppKit(axRect, globalHeight: globalHeight)
    }
}
