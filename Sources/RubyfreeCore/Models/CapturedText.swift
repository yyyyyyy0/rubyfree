import Foundation
import CoreGraphics

/// Text captured from another application (Accessibility or OCR), already sanitized.
///
/// AX/OCR output is untrusted external input (the source app may be adversarial), so
/// the failable initializer clamps length, strips control / bidirectional / zero-width
/// characters, NFC-normalizes, and validates the rect. `text` is never persisted or
/// logged (see PRIVACY.md / dev rules).
public struct CapturedText: Equatable, Sendable {
    public let text: String
    public let screenRect: CGRect
    public let source: CaptureSource

    /// Max characters kept from a single capture (DoS guard against huge AX/OCR returns).
    public static let maxLength = 256

    /// Sanitizing initializer for untrusted external text. Returns nil when there is no
    /// usable content after cleaning, or the rect is invalid.
    public init?(rawText: String, screenRect: CGRect, source: CaptureSource) {
        guard CapturedText.isValidRect(screenRect) else { return nil }
        let cleaned = CapturedText.sanitize(rawText)
        guard !cleaned.isEmpty else { return nil }
        self.text = cleaned
        self.screenRect = screenRect
        self.source = source
    }

    /// Trusted initializer for internally-constructed values (tests, composition).
    public init(text: String, screenRect: CGRect, source: CaptureSource) {
        self.text = text
        self.screenRect = screenRect
        self.source = source
    }

    static func isValidRect(_ r: CGRect) -> Bool {
        r.origin.x.isFinite && r.origin.y.isFinite
            && r.size.width.isFinite && r.size.height.isFinite
            && r.size.width >= 0 && r.size.height >= 0
    }

    /// Strip disallowed scalars, collapse whitespace, NFC-normalize, clamp length.
    static func sanitize(_ raw: String) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars where !isDisallowed(scalar) {
            kept.append(scalar)
        }
        let normalized = String(kept).precomposedStringWithCanonicalMapping
        let collapsed = normalized
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        let clamped = collapsed.count > maxLength ? String(collapsed.prefix(maxLength)) : collapsed
        return clamped.trimmingCharacters(in: .whitespaces)
    }

    /// Control chars (except tab/newline, which the whitespace collapse handles),
    /// bidirectional controls, and zero-width characters.
    static func isDisallowed(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x09, 0x0A, 0x0D:
            return false
        case 0x00...0x1F, 0x7F...0x9F:
            return true
        case 0x200B...0x200F,  // zero-width + LTR/RTL marks
             0x202A...0x202E,  // bidi embeddings / overrides
             0x2066...0x2069,  // bidi isolates
             0xFEFF:           // zero-width no-break space / BOM
            return true
        default:
            return false
        }
    }
}
