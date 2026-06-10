/// A hiragana reading for a word. `isUncertain` marks readings the engine is not
/// confident about (e.g. homographs with multiple readings) so the UI can de-emphasise
/// them — a learning tool must not present a wrong reading with full confidence.
public struct Reading: Equatable, Sendable {
    public let hiragana: String
    public let isUncertain: Bool

    public init(hiragana: String, isUncertain: Bool = false) {
        self.hiragana = hiragana
        self.isUncertain = isUncertain
    }
}
