import Foundation
import RubyfreeCore

/// Persists rubyfree's *settings* (preferences only — never user/screen content) so they
/// survive relaunch. Kept deliberately tiny: only what the user can configure.
public protocol SettingsStoring: AnyObject {
    /// Whether hover-to-furigana is active. Defaults to `true` on first launch.
    var isEnabled: Bool { get set }
    /// Identifier of the selected ``RubyTheme``. Defaults to ``RubyTheme/default`` on first
    /// launch. Stores only the palette id (no user content).
    var themeID: String { get set }
}

/// `UserDefaults`-backed settings. Storing only a boolean preference and a theme id (no user
/// data) keeps this within the project's "never persist user content" rule.
public final class UserDefaultsSettingsStore: SettingsStoring {

    private let defaults: UserDefaults
    private static let isEnabledKey = "rubyfree.isEnabled"
    private static let themeIDKey = "rubyfree.themeID"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        // Absent key → enabled by default (a fresh install should just work).
        get { defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }

    public var themeID: String {
        // Absent key → the default theme (preserves the original appearance).
        get { defaults.string(forKey: Self.themeIDKey) ?? RubyTheme.default.id }
        set { defaults.set(newValue, forKey: Self.themeIDKey) }
    }
}
