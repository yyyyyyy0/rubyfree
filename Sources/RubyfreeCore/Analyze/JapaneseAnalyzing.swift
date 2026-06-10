/// The single replacement boundary for Japanese analysis. Splitting and reading are
/// produced together (MeCab-style engines return both in one pass), so this — not a
/// separate reading-only protocol — is what a future MeCab implementation swaps in.
public protocol JapaneseAnalyzing: Sendable {
    /// Tokenize `text` into surface forms with readings (hiragana) where available.
    func analyze(_ text: String) -> [AnalyzedToken]
}
