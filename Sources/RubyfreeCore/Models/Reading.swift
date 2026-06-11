/// A hiragana reading for a word. `isUncertain` marks readings the engine is not
/// confident about (e.g. homographs with multiple readings) so the UI can de-emphasise
/// them — a learning tool must not present a wrong reading with full confidence.
///
/// `hiragana` is the primary reading; `alternatives` holds additional dictionary
/// readings for the same surface (a word may legitimately have several, e.g. 角 →
/// かど／つの). The UI may show alternatives after the primary so the learner sees the
/// full set rather than a single — possibly wrong — guess.
public struct Reading: Equatable, Sendable {
    public let hiragana: String
    public let alternatives: [String]
    public let isUncertain: Bool

    public init(hiragana: String, alternatives: [String] = [], isUncertain: Bool = false) {
        self.hiragana = hiragana
        self.alternatives = alternatives
        self.isUncertain = isUncertain
    }

    /// All readings, primary first, with duplicates and the primary removed from the
    /// tail so `[hiragana] + alternatives` never repeats a value.
    public var allReadings: [String] {
        var seen: Set<String> = [hiragana]
        var result = [hiragana]
        for alt in alternatives where !seen.contains(alt) {
            seen.insert(alt)
            result.append(alt)
        }
        return result
    }
}
