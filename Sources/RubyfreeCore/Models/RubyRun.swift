/// A logical ruby unit: a base (kanji) string and its ruby (hiragana) gloss. Carries no
/// coordinates — final on-screen placement is decided at render time from CTLine
/// metrics, not here.
public struct RubyRun: Equatable, Sendable {
    public let base: String
    public let ruby: String
    /// Additional readings for the same base, beyond `ruby`. Empty when the word has a
    /// single known reading. The renderer decides how to present them (e.g. `主／代`).
    public let alternatives: [String]
    public let isUncertain: Bool

    public init(base: String, ruby: String, alternatives: [String] = [], isUncertain: Bool = false) {
        self.base = base
        self.ruby = ruby
        self.alternatives = alternatives
        self.isUncertain = isUncertain
    }
}
