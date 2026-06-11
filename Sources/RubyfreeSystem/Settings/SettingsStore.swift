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
    /// Base (body) font size in points for the overlay. Clamped to ``SettingsBounds/fontSize``.
    var fontSize: Int { get set }
    /// Max readings shown per word (primary + alternatives). Clamped to ``SettingsBounds/maxReadings``.
    var maxReadings: Int { get set }
    /// Hover-settle delay in seconds before a capture fires. Clamped to ``SettingsBounds/settleDelay``.
    var settleDelay: Double { get set }
    /// Persisted settings-schema version (for future migrations). Reads as the current
    /// version when absent.
    var schemaVersion: Int { get set }
}

/// Valid ranges and defaults for the numeric settings. Reads are clamped to these so a
/// hand-edited or stale `UserDefaults` value can never push the overlay into a broken state
/// (mirrors ``RubyTheme/preset(id:)``'s unknown-id → default fallback).
public enum SettingsBounds {
    public static let fontSize = 16...32
    public static let fontSizeDefault = 22
    public static let maxReadings = 1...4
    public static let maxReadingsDefault = 3
    public static let settleDelay = 0.15...1.0
    public static let settleDelayDefault = 0.35
    /// Current settings-schema version. Bump only on a breaking key change + migration.
    public static let currentSchemaVersion = 1

    static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

/// `UserDefaults`-backed settings. Stores only preferences (booleans, a theme id, numeric
/// display/behaviour values) — never user/screen content — keeping this within the project's
/// "never persist user content" rule.
public final class UserDefaultsSettingsStore: SettingsStoring {

    private let defaults: UserDefaults
    private static let isEnabledKey = "rubyfree.isEnabled"
    private static let themeIDKey = "rubyfree.themeID"
    private static let fontSizeKey = "rubyfree.fontSize"
    private static let maxReadingsKey = "rubyfree.maxReadings"
    private static let settleDelayKey = "rubyfree.settleDelay"
    private static let schemaVersionKey = "rubyfree.schemaVersion"

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

    public var fontSize: Int {
        get { clampedInt(Self.fontSizeKey, default: SettingsBounds.fontSizeDefault, range: SettingsBounds.fontSize) }
        set { defaults.set(SettingsBounds.clamp(newValue, to: SettingsBounds.fontSize), forKey: Self.fontSizeKey) }
    }

    public var maxReadings: Int {
        get { clampedInt(Self.maxReadingsKey, default: SettingsBounds.maxReadingsDefault, range: SettingsBounds.maxReadings) }
        set { defaults.set(SettingsBounds.clamp(newValue, to: SettingsBounds.maxReadings), forKey: Self.maxReadingsKey) }
    }

    public var settleDelay: Double {
        get {
            guard defaults.object(forKey: Self.settleDelayKey) != nil else { return SettingsBounds.settleDelayDefault }
            return SettingsBounds.clamp(defaults.double(forKey: Self.settleDelayKey), to: SettingsBounds.settleDelay)
        }
        set { defaults.set(SettingsBounds.clamp(newValue, to: SettingsBounds.settleDelay), forKey: Self.settleDelayKey) }
    }

    public var schemaVersion: Int {
        get {
            guard defaults.object(forKey: Self.schemaVersionKey) != nil else { return SettingsBounds.currentSchemaVersion }
            return defaults.integer(forKey: Self.schemaVersionKey)
        }
        set { defaults.set(newValue, forKey: Self.schemaVersionKey) }
    }

    /// Read an Int key, clamped to `range`; absent → `default`.
    private func clampedInt(_ key: String, default fallback: Int, range: ClosedRange<Int>) -> Int {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return SettingsBounds.clamp(defaults.integer(forKey: key), to: range)
    }
}
