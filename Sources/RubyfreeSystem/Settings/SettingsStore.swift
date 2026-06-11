import Foundation

/// Persists rubyfree's *settings* (preferences only — never user/screen content) so they
/// survive relaunch. Kept deliberately tiny: only what the user can configure.
public protocol SettingsStoring: AnyObject {
    /// Whether hover-to-furigana is active. Defaults to `true` on first launch.
    var isEnabled: Bool { get set }
}

/// `UserDefaults`-backed settings. Storing only a boolean preference (no user data) keeps
/// this within the project's "never persist user content" rule.
public final class UserDefaultsSettingsStore: SettingsStoring {

    private let defaults: UserDefaults
    private static let isEnabledKey = "rubyfree.isEnabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        // Absent key → enabled by default (a fresh install should just work).
        get { defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }
}
