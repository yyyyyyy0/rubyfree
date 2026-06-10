/// One token from morphological analysis: surface form, its reading (nil if none/not
/// applicable), and its range in the original string. Splitting and reading come from
/// a single `JapaneseAnalyzing` pass (MeCab-style engines return both together).
public struct AnalyzedToken: Equatable, Sendable {
    public let surface: String
    public let reading: Reading?
    public let range: Range<String.Index>

    public init(surface: String, reading: Reading?, range: Range<String.Index>) {
        self.surface = surface
        self.reading = reading
        self.range = range
    }

    /// True if the surface contains a kanji (i.e. worth glossing with ruby).
    public var containsKanji: Bool { surface.containsKanji }
}
