import AppKit
import RubyfreeCore

// MARK: - ThemeDTO

/// Codable wire format for a user-edited custom theme. Version field guards against future
/// schema changes; current format: `{"v":1,"foreground":"#RRGGBBAA",...}` with 5 RGBA hex
/// values. All colour components stored in sRGB after normalisation at write time.
struct ThemeDTO: Codable {
    let v: Int
    let foreground: String
    let ruby: String
    let uncertain: String
    let chipBackground: String
    let chipStroke: String
}

// MARK: - ThemeCodec

/// Converts between ``RubyTheme`` (CGColor components) and the JSON string stored under
/// `rubyfree.customTheme` in UserDefaults. Colour round-trip always goes through sRGB so
/// values written on any display profile remain numerically stable (mirrors the approach in
/// `RubyRenderer.applyChipColors`).
///
/// All methods are pure / static — no stored state.
public enum ThemeCodec {

    // MARK: Encode

    /// Serialise `theme` as a JSON string.
    /// - Returns: JSON string, or `nil` if any colour conversion fails.
    public static func encode(_ theme: RubyTheme) -> String? {
        guard
            let fg   = hexRGBA(from: theme.foregroundColor),
            let ruby = hexRGBA(from: theme.rubyColor),
            let unc  = hexRGBA(from: theme.uncertainColor),
            let bg   = hexRGBA(from: theme.chipBackgroundColor),
            let str  = hexRGBA(from: theme.chipStrokeColor)
        else { return nil }

        let dto = ThemeDTO(v: 1,
                           foreground: fg,
                           ruby: ruby,
                           uncertain: unc,
                           chipBackground: bg,
                           chipStroke: str)
        guard let data = try? JSONEncoder().encode(dto) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Decode

    /// Parse a JSON string back into a ``RubyTheme`` with `id: "custom"`.
    /// - Returns: Theme, or `nil` on any parse / conversion error.
    public static func decode(_ json: String) -> RubyTheme? {
        guard
            let data = json.data(using: .utf8),
            let dto  = try? JSONDecoder().decode(ThemeDTO.self, from: data),
            dto.v == 1,
            let fg   = cgColor(from: dto.foreground),
            let ruby = cgColor(from: dto.ruby),
            let unc  = cgColor(from: dto.uncertain),
            let bg   = cgColor(from: dto.chipBackground),
            let str  = cgColor(from: dto.chipStroke)
        else { return nil }

        return RubyTheme(
            id: "custom",
            name: "カスタム",
            foregroundColor: fg,
            rubyColor: ruby,
            uncertainColor: unc,
            chipBackgroundColor: bg,
            chipStrokeColor: str
        )
    }

    // MARK: - Helpers (public for testability)

    /// Convert a `CGColor` to an 8-char hex string `#RRGGBBAA`, normalised to sRGB.
    /// Returns `nil` if the colour cannot be converted to sRGB.
    public static func hexRGBA(from cgColor: CGColor) -> String? {
        // Convert via NSColor so we can use `usingColorSpace(.sRGB)` — the same technique
        // RubyRenderer uses when bridging CGColor to NSColor at the drawing boundary.
        guard
            let nsColor = NSColor(cgColor: cgColor),
            let srgb = nsColor.usingColorSpace(.sRGB)
        else { return nil }

        // Clamp components to 0…1 to guard against out-of-gamut values on wide-colour displays.
        let r = clamp01(srgb.redComponent)
        let g = clamp01(srgb.greenComponent)
        let b = clamp01(srgb.blueComponent)
        let a = clamp01(srgb.alphaComponent)

        return String(format: "#%02X%02X%02X%02X",
                      UInt8(r * 255 + 0.5),
                      UInt8(g * 255 + 0.5),
                      UInt8(b * 255 + 0.5),
                      UInt8(a * 255 + 0.5))
    }

    /// Parse an `#RRGGBBAA` hex string back to a `CGColor` in the sRGB colour space.
    /// Clamps each component to 0…1 to defend against hand-edited values.
    public static func cgColor(from hex: String) -> CGColor? {
        let stripped = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard stripped.count == 8,
              let value = UInt32(stripped, radix: 16) else { return nil }

        let r = clamp01(Double((value >> 24) & 0xFF) / 255)
        let g = clamp01(Double((value >> 16) & 0xFF) / 255)
        let b = clamp01(Double((value >> 8)  & 0xFF) / 255)
        let a = clamp01(Double( value        & 0xFF) / 255)

        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       components: [r, g, b, a])
    }

    private static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
    private static func clamp01(_ v: CGFloat) -> CGFloat { min(max(v, 0), 1) }
}
