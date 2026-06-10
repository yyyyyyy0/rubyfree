/// A logical ruby unit: a base (kanji) string and its ruby (hiragana) gloss. Carries no
/// coordinates — final on-screen placement is decided at render time from CTLine
/// metrics, not here.
public struct RubyRun: Equatable, Sendable {
    public let base: String
    public let ruby: String
    public let isUncertain: Bool

    public init(base: String, ruby: String, isUncertain: Bool = false) {
        self.base = base
        self.ruby = ruby
        self.isUncertain = isUncertain
    }
}
