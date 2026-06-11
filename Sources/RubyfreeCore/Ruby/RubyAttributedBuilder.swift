import Foundation
import CoreText
import CoreGraphics

// MARK: - RubyStyle

/// Visual styling parameters for ruby-annotated text.
/// All colours are expressed as ``CGColor`` and fonts as ``CTFont`` so this
/// type stays AppKit-free.
public struct RubyStyle: Sendable {
    /// Point size of the base (body) text.
    public let fontSize: CGFloat
    /// Font family name for the base text.
    public let fontName: String
    /// Foreground colour of the base (kanji) text. On the dark overlay chip this is a
    /// near-white so the base stays readable.
    public let foregroundColor: CGColor
    /// Colour of the furigana (ruby) gloss — the highlighted element. A bright accent on
    /// the dark chip so the reading is the most legible part.
    public let rubyColor: CGColor
    /// Colour for the ruby of *uncertain* readings — dimmed so the reader knows the
    /// reading may be wrong.
    public let uncertainColor: CGColor
    /// Ruby glyph size as a fraction of `fontSize` (furigana is conventionally ~0.5;
    /// bumped up here for legibility).
    public let rubyScale: CGFloat
    /// Extra vertical gap (points) lifted between the ruby gloss and the base glyphs so
    /// the furigana doesn't visually touch the kanji.
    public let rubyGap: CGFloat
    /// Maximum number of readings shown per word (primary + alternatives). Caps the ruby
    /// width so a many-reading word (e.g. 山茶花 has 4) stays legible and doesn't blow out
    /// the chip; surplus readings are dropped from the display only, not the model.
    public let maxReadings: Int

    public init(
        fontSize: CGFloat = 22,
        fontName: String = "HiraginoSans-W3",
        foregroundColor: CGColor = CGColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0),
        rubyColor: CGColor = CGColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1.0),
        uncertainColor: CGColor = CGColor(red: 0.70, green: 0.62, blue: 0.40, alpha: 1.0),
        rubyScale: CGFloat = 0.6,
        rubyGap: CGFloat = 3,
        maxReadings: Int = 3
    ) {
        self.fontSize = fontSize
        self.fontName = fontName
        self.foregroundColor = foregroundColor
        self.rubyColor = rubyColor
        self.uncertainColor = uncertainColor
        self.rubyScale = rubyScale
        self.rubyGap = rubyGap
        self.maxReadings = max(1, maxReadings)
    }
}

// MARK: - RubyAttributedBuilder

/// Builds an ``NSAttributedString`` from a sequence of ``RubyRun`` values,
/// attaching a `CTRubyAnnotation` (via `kCTRubyAnnotationAttributeName`) to
/// each base character run so that CoreText renders the hiragana gloss above
/// the kanji.
///
/// AppKit's standard drawing pipeline honours `kCTRubyAnnotationAttributeName`
/// natively; no manual CTLine drawing is required.
public struct RubyAttributedBuilder: Sendable {
    public init() {}

    /// Compose all ``RubyRun`` values into a single attributed string.
    /// Runs are separated by a thin space (U+2009) so adjacent ruby glosses
    /// don't collide visually.
    ///
    /// - Parameters:
    ///   - runs: The ruby runs to render; an empty array returns an empty string.
    ///   - style: Visual styling; defaults to ``RubyStyle/init()``.
    /// - Returns: An ``NSAttributedString`` with CoreText ruby annotations applied.
    public func build(_ runs: [RubyRun], style: RubyStyle = .init()) -> NSAttributedString {
        guard !runs.isEmpty else { return NSAttributedString() }

        let baseFont = CTFontCreateWithName(style.fontName as CFString, style.fontSize, nil)
        let rubyFontSize = style.fontSize * style.rubyScale
        let rubyFont = CTFontCreateWithName(style.fontName as CFString, rubyFontSize, nil)

        let result = NSMutableAttributedString()

        for (index, run) in runs.enumerated() {
            // Base (kanji) keeps the high-contrast foreground; the ruby carries the
            // uncertainty signal by dimming, so the body text stays readable.
            let rubyColor = run.isUncertain ? style.uncertainColor : style.rubyColor

            // Build the CTRubyAnnotation for this run.
            // We use CTRubyAnnotationCreateWithAttributes so we can supply a
            // dedicated ruby font; the ruby text goes in the .before (above) slot.
            // When a word has several known readings, show them (up to maxReadings)
            // joined by a full-width slash so the learner sees the set rather than one
            // guess: 角 → かど／つの
            let rubyString = ([run.ruby] + run.alternatives)
                .prefix(style.maxReadings)
                .joined(separator: "／")
            let rubyText = rubyString as CFString
            let rubyAttr = CTRubyAnnotationCreateWithAttributes(
                .auto,          // alignment
                // No overhang: a wide multi-reading gloss must not spill over the adjacent
                // run/kanji (that overlap was the "複数読みが一部被る" bug). With .none the
                // base advance widens to fit the ruby instead of overhanging neighbours.
                .none,          // overhang
                .before,        // position: above the base
                rubyText,
                [
                    kCTFontAttributeName: rubyFont,
                    kCTForegroundColorAttributeName: rubyColor,
                    // Lift the ruby slightly so it doesn't touch the kanji below it.
                    kCTBaselineOffsetAttributeName: style.rubyGap as CFNumber,
                ] as CFDictionary
            )

            // Attributes for the base (kanji) string.
            let baseAttributes: [NSAttributedString.Key: Any] = [
                kCTFontAttributeName as NSAttributedString.Key: baseFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: style.foregroundColor,
                kCTRubyAnnotationAttributeName as NSAttributedString.Key: rubyAttr,
            ]

            result.append(NSAttributedString(string: run.base, attributes: baseAttributes))

            // Insert a thin space between runs (not after the last one).
            if index < runs.count - 1 {
                let spaceAttributes: [NSAttributedString.Key: Any] = [
                    kCTFontAttributeName as NSAttributedString.Key: baseFont,
                    kCTForegroundColorAttributeName as NSAttributedString.Key: style.foregroundColor,
                ]
                result.append(NSAttributedString(string: "\u{2009}", attributes: spaceAttributes))
            }
        }

        return result
    }
}
