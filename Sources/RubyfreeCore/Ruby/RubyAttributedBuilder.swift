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
    /// Foreground colour for certain (confident) runs.
    public let foregroundColor: CGColor
    /// Foreground colour for uncertain runs — typically a lighter tint of
    /// ``foregroundColor`` so the reader knows the reading may be wrong.
    public let uncertainColor: CGColor

    public init(
        fontSize: CGFloat = 18,
        fontName: String = "HiraginoSans-W3",
        foregroundColor: CGColor = CGColor(gray: 0.0, alpha: 1.0),
        uncertainColor: CGColor = CGColor(gray: 0.5, alpha: 1.0)
    ) {
        self.fontSize = fontSize
        self.fontName = fontName
        self.foregroundColor = foregroundColor
        self.uncertainColor = uncertainColor
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
        // Ruby (furigana) glyph size is conventionally half the base size.
        let rubyFontSize = style.fontSize * 0.5
        let rubyFont = CTFontCreateWithName(style.fontName as CFString, rubyFontSize, nil)

        let result = NSMutableAttributedString()

        for (index, run) in runs.enumerated() {
            let color = run.isUncertain ? style.uncertainColor : style.foregroundColor

            // Build the CTRubyAnnotation for this run.
            // We use CTRubyAnnotationCreateWithAttributes so we can supply a
            // dedicated ruby font; the ruby text goes in the .before (above) slot.
            let rubyText = run.ruby as CFString
            let rubyAttr = CTRubyAnnotationCreateWithAttributes(
                .auto,          // alignment
                .auto,          // overhang
                .before,        // position: above the base
                rubyText,
                [
                    kCTFontAttributeName: rubyFont,
                    kCTForegroundColorAttributeName: color,
                ] as CFDictionary
            )

            // Attributes for the base (kanji) string.
            let baseAttributes: [NSAttributedString.Key: Any] = [
                kCTFontAttributeName as NSAttributedString.Key: baseFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: color,
                kCTRubyAnnotationAttributeName as NSAttributedString.Key: rubyAttr,
            ]

            result.append(NSAttributedString(string: run.base, attributes: baseAttributes))

            // Insert a thin space between runs (not after the last one).
            if index < runs.count - 1 {
                let spaceAttributes: [NSAttributedString.Key: Any] = [
                    kCTFontAttributeName as NSAttributedString.Key: baseFont,
                    kCTForegroundColorAttributeName as NSAttributedString.Key: color,
                ]
                result.append(NSAttributedString(string: "\u{2009}", attributes: spaceAttributes))
            }
        }

        return result
    }
}
