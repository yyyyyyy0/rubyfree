import CoreGraphics

// MARK: - RubyTheme

/// A user-selectable colour palette for the ruby overlay. Bundles both the *text* colours
/// (consumed by ``RubyStyle`` / ``RubyAttributedBuilder`` when composing the attributed
/// string) and the *chip* colours (background + stroke, consumed by the overlay renderer)
/// so a single selection drives the whole appearance.
///
/// AppKit-free: colours are ``CGColor`` so this type lives in `RubyfreeCore`. The app layer
/// converts to `NSColor` at the drawing boundary.
///
/// A theme carries only its own presentation values — no user/screen content — so persisting
/// the selected ``id`` stays within the project's "never persist user data" rule.
public struct RubyTheme: Sendable {
    /// Stable identifier used for persistence and menu selection (never localised).
    public let id: String
    /// Human-facing name shown in the theme menu.
    public let name: String

    // --- Text colours (fed into RubyStyle) ---

    /// Foreground colour of the base (kanji) text.
    public let foregroundColor: CGColor
    /// Colour of the furigana (ruby) gloss — the highlighted element.
    public let rubyColor: CGColor
    /// Dimmed ruby colour for *uncertain* readings, signalling the reading may be wrong.
    public let uncertainColor: CGColor

    // --- Chip colours (consumed by the overlay renderer) ---

    /// Fill colour of the rounded backdrop chip.
    public let chipBackgroundColor: CGColor
    /// Stroke (border) colour of the backdrop chip.
    public let chipStrokeColor: CGColor

    public init(
        id: String,
        name: String,
        foregroundColor: CGColor,
        rubyColor: CGColor,
        uncertainColor: CGColor,
        chipBackgroundColor: CGColor,
        chipStrokeColor: CGColor
    ) {
        self.id = id
        self.name = name
        self.foregroundColor = foregroundColor
        self.rubyColor = rubyColor
        self.uncertainColor = uncertainColor
        self.chipBackgroundColor = chipBackgroundColor
        self.chipStrokeColor = chipStrokeColor
    }

    /// Derive a ``RubyStyle`` from this theme's text colours, keeping ``RubyStyle``'s other
    /// defaults (font, sizes, ruby gap, max readings) untouched.
    public func makeStyle() -> RubyStyle {
        RubyStyle(
            foregroundColor: foregroundColor,
            rubyColor: rubyColor,
            uncertainColor: uncertainColor
        )
    }
}

// MARK: - Presets

extension RubyTheme {
    /// Dark chip with a gold gloss. The original (pre-theme) appearance — keeping it the
    /// default means existing users see no visual change.
    public static let dark = RubyTheme(
        id: "dark",
        name: "ダーク",
        foregroundColor: CGColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0),
        rubyColor: CGColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1.0),
        uncertainColor: CGColor(red: 0.70, green: 0.62, blue: 0.40, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.92),
        chipStrokeColor: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18)
    )

    /// Light chip with dark text and a burnt-orange gloss, for use over dark backgrounds or
    /// by readers who prefer a bright chip.
    public static let light = RubyTheme(
        id: "light",
        name: "ライト",
        foregroundColor: CGColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0),
        rubyColor: CGColor(red: 0.82, green: 0.34, blue: 0.0, alpha: 1.0),
        uncertainColor: CGColor(red: 0.55, green: 0.45, blue: 0.32, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 0.94),
        chipStrokeColor: CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.22)
    )

    /// Maximum-legibility palette: pure-black chip, pure-white base, bright-yellow gloss.
    public static let highContrast = RubyTheme(
        id: "highContrast",
        name: "高コントラスト",
        foregroundColor: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        rubyColor: CGColor(red: 1.0, green: 0.92, blue: 0.10, alpha: 1.0),
        uncertainColor: CGColor(red: 0.72, green: 0.68, blue: 0.34, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
        chipStrokeColor: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
    )

    /// Warm paper chip with dark-brown text and a maroon gloss — a softer, low-glare look.
    public static let sepia = RubyTheme(
        id: "sepia",
        name: "セピア",
        foregroundColor: CGColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 1.0),
        rubyColor: CGColor(red: 0.70, green: 0.20, blue: 0.10, alpha: 1.0),
        uncertainColor: CGColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.93, green: 0.87, blue: 0.73, alpha: 0.95),
        chipStrokeColor: CGColor(red: 0.40, green: 0.30, blue: 0.16, alpha: 0.30)
    )

    /// Deep-navy chip with near-white text and a cyan gloss.
    public static let ocean = RubyTheme(
        id: "ocean",
        name: "オーシャン",
        foregroundColor: CGColor(red: 0.92, green: 0.95, blue: 0.98, alpha: 1.0),
        rubyColor: CGColor(red: 0.40, green: 0.82, blue: 0.95, alpha: 1.0),
        uncertainColor: CGColor(red: 0.50, green: 0.62, blue: 0.72, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.06, green: 0.11, blue: 0.20, alpha: 0.93),
        chipStrokeColor: CGColor(red: 0.50, green: 0.75, blue: 0.95, alpha: 0.25)
    )

    /// Dark-green chip with cream text and a lime gloss.
    public static let forest = RubyTheme(
        id: "forest",
        name: "フォレスト",
        foregroundColor: CGColor(red: 0.93, green: 0.96, blue: 0.90, alpha: 1.0),
        rubyColor: CGColor(red: 0.56, green: 0.90, blue: 0.45, alpha: 1.0),
        uncertainColor: CGColor(red: 0.55, green: 0.66, blue: 0.50, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.06, green: 0.14, blue: 0.09, alpha: 0.93),
        chipStrokeColor: CGColor(red: 0.50, green: 0.80, blue: 0.45, alpha: 0.25)
    )

    /// Soft pink chip with plum text and a rose gloss.
    public static let sakura = RubyTheme(
        id: "sakura",
        name: "サクラ",
        foregroundColor: CGColor(red: 0.30, green: 0.12, blue: 0.20, alpha: 1.0),
        rubyColor: CGColor(red: 0.85, green: 0.20, blue: 0.45, alpha: 1.0),
        uncertainColor: CGColor(red: 0.62, green: 0.45, blue: 0.52, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.99, green: 0.93, blue: 0.95, alpha: 0.95),
        chipStrokeColor: CGColor(red: 0.70, green: 0.30, blue: 0.45, alpha: 0.28)
    )

    /// Deep-purple chip with white text and a lavender gloss.
    public static let grape = RubyTheme(
        id: "grape",
        name: "グレープ",
        foregroundColor: CGColor(red: 0.95, green: 0.93, blue: 0.98, alpha: 1.0),
        rubyColor: CGColor(red: 0.80, green: 0.60, blue: 1.0, alpha: 1.0),
        uncertainColor: CGColor(red: 0.62, green: 0.55, blue: 0.70, alpha: 1.0),
        chipBackgroundColor: CGColor(red: 0.14, green: 0.08, blue: 0.20, alpha: 0.93),
        chipStrokeColor: CGColor(red: 0.70, green: 0.55, blue: 0.95, alpha: 0.28)
    )

    /// All presets in menu display order (dark / light / high-contrast first, then the
    /// colour palettes).
    public static let allPresets: [RubyTheme] = [
        .dark, .light, .highContrast,
        .sepia, .ocean, .forest, .sakura, .grape,
    ]

    /// The default theme on a fresh install (preserves the original appearance).
    public static let `default`: RubyTheme = .dark

    /// Look up a preset by ``id``; falls back to ``default`` for an unknown/legacy id so a
    /// stale persisted value can never leave the overlay unstyled.
    public static func preset(id: String) -> RubyTheme {
        allPresets.first { $0.id == id } ?? .default
    }
}
