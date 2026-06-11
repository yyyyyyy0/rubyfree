import Foundation

/// Converts a sequence of ``AnalyzedToken`` values into ``RubyRun`` values,
/// keeping only those tokens that both contain kanji and carry a reading.
/// Tokens without kanji, or without a reading, are silently skipped.
/// Input order is preserved.
public struct RubyComposer: Sendable {
    public init() {}

    /// Returns one ``RubyRun`` for every token that contains kanji **and** has a
    /// non-nil reading; all other tokens are dropped.
    public func compose(_ tokens: [AnalyzedToken]) -> [RubyRun] {
        tokens.compactMap { token in
            guard token.containsKanji, let reading = token.reading else { return nil }
            // Use `allReadings` (primary first, de-duplicated) so the rendered ruby can
            // never show a repeated gloss like かど／かど even if the source data has dupes.
            let readings = reading.allReadings
            return RubyRun(
                base: token.surface,
                ruby: readings[0],
                alternatives: Array(readings.dropFirst()),
                isUncertain: reading.isUncertain
            )
        }
    }
}
