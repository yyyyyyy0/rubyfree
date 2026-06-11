import CoreGraphics
import RubyfreeCore
import TinyTest

func testRubyTheme(_ t: TinyTest) {
    // ------------------------------------------------------------------
    // 1. Presets are distinct, non-empty, and carry stable ids/names.
    // ------------------------------------------------------------------
    let presets = RubyTheme.allPresets
    // At least the three originals; more palettes may be added over time.
    t.expectTrue(presets.count >= 3, "at least three presets")
    let ids = presets.map { $0.id }
    t.expectTrue(ids.contains("dark"), "dark preset present")
    t.expectTrue(ids.contains("light"), "light preset present")
    t.expectTrue(ids.contains("highContrast"), "highContrast preset present")
    // Ids are unique (a duplicate would break menu radio selection).
    t.expectEqual(Set(ids).count, presets.count)
    for theme in presets {
        t.expectTrue(!theme.name.isEmpty, "theme \(theme.id) must have a display name")
    }

    // ------------------------------------------------------------------
    // 2. Default is dark and preserves the original appearance.
    // ------------------------------------------------------------------
    t.expectEqual(RubyTheme.default.id, "dark")

    // ------------------------------------------------------------------
    // 3. preset(id:) round-trips a known id and falls back to default for unknown ids.
    // ------------------------------------------------------------------
    t.expectEqual(RubyTheme.preset(id: "light").id, "light")
    t.expectEqual(RubyTheme.preset(id: "highContrast").id, "highContrast")
    t.expectEqual(RubyTheme.preset(id: "does-not-exist").id, RubyTheme.default.id)
    t.expectEqual(RubyTheme.preset(id: "").id, RubyTheme.default.id)

    // ------------------------------------------------------------------
    // 4. makeStyle() maps the theme's text colours onto a RubyStyle, keeping other
    //    RubyStyle defaults intact.
    // ------------------------------------------------------------------
    let theme = RubyTheme.light
    let style = theme.makeStyle()
    t.expectEqual(style.foregroundColor, theme.foregroundColor)
    t.expectEqual(style.rubyColor, theme.rubyColor)
    t.expectEqual(style.uncertainColor, theme.uncertainColor)
    // Untouched defaults (sanity: makeStyle must not alter layout/sizing).
    let defaults = RubyStyle()
    t.expectEqual(style.fontSize, defaults.fontSize)
    t.expectEqual(style.maxReadings, defaults.maxReadings)

    // ------------------------------------------------------------------
    // 5. The dark preset's text colours equal RubyStyle's own defaults, proving the
    //    default theme reproduces the original (pre-theme) look exactly.
    // ------------------------------------------------------------------
    let darkStyle = RubyTheme.dark.makeStyle()
    t.expectEqual(darkStyle.foregroundColor, defaults.foregroundColor)
    t.expectEqual(darkStyle.rubyColor, defaults.rubyColor)
    t.expectEqual(darkStyle.uncertainColor, defaults.uncertainColor)
}
