import Foundation
import AppKit
import RubyfreeCore
import RubyfreeSystem
import TinyTest

func testThemeCodec(_ t: TinyTest) {

    // MARK: hexRGBA round-trip

    // 1. Basic round-trip: CGColor → hex → CGColor gives identical sRGB components.
    let red = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      components: [1.0, 0.0, 0.0, 1.0])!
    let redHex = ThemeCodec.hexRGBA(from: red)
    t.expectEqual(redHex, "#FF0000FF")
    if let h = redHex, let back = ThemeCodec.cgColor(from: h) {
        let cs = back.components ?? []
        t.expectTrue(cs.count >= 4, "back has 4 components")
        t.expectTrue(abs(cs[0] - 1.0) < 1e-3, "red R round-trips")
        t.expectTrue(abs(cs[1] - 0.0) < 1e-3, "red G round-trips")
        t.expectTrue(abs(cs[2] - 0.0) < 1e-3, "red B round-trips")
        t.expectTrue(abs(cs[3] - 1.0) < 1e-3, "red A round-trips")
    } else {
        t.expectTrue(false, "red hex should decode back")
    }

    // 2. Semi-transparent colour preserves alpha (0.5 → 0x80 = 128).
    let semiBlue = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           components: [0.0, 0.0, 1.0, 0.5])!
    let blueHex = ThemeCodec.hexRGBA(from: semiBlue)
    t.expectEqual(blueHex, "#0000FF80")

    // 3. sRGB normalisation: a CGColor created in the generic colour space must still
    //    produce a valid hex without crashing.
    let generic = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    let genHex = ThemeCodec.hexRGBA(from: generic)
    t.expectTrue(genHex != nil, "generic CGColor converts to hex")
    t.expectTrue(genHex?.hasPrefix("#") == true, "hex starts with #")
    t.expectTrue(genHex?.count == 9, "hex is #RRGGBBAA (9 chars)")

    // MARK: Decode failure → nil

    // 4. Malformed JSON returns nil.
    t.expectTrue(ThemeCodec.decode("not json") == nil, "malformed JSON → nil")

    // 5. Wrong version field returns nil.
    let wrongVersionJSON = buildJSON(v: 2, hex: "#FF0000FF")
    t.expectTrue(ThemeCodec.decode(wrongVersionJSON) == nil, "v != 1 returns nil")

    // 6. Invalid hex string inside valid JSON returns nil.
    let badHexJSON = buildJSON(v: 1, hex: "ZZZZZZZZ")
    t.expectTrue(ThemeCodec.decode(badHexJSON) == nil, "invalid hex returns nil")

    // MARK: Full encode → decode round-trip

    // 7. Encode a RubyTheme preset and decode it back; verify the id is "custom" and
    //    the colours are numerically close.
    let preset = RubyTheme.dark
    guard let json = ThemeCodec.encode(preset) else {
        t.expectTrue(false, "encode should not fail on a preset"); return
    }
    guard let decoded = ThemeCodec.decode(json) else {
        t.expectTrue(false, "decode should succeed on own encode output"); return
    }
    t.expectEqual(decoded.id, "custom")
    t.expectEqual(decoded.name, "カスタム")

    // Spot-check foreground R component (should be very close to original after sRGB round-trip).
    if let fgComps = decoded.foregroundColor.components, fgComps.count >= 3 {
        // RubyTheme.dark foreground is (0.96, 0.96, 0.96, 1.0) in sRGB
        t.expectTrue(abs(Double(fgComps[0]) - 0.96) < 0.01, "foreground R round-trips within 1%")
    } else {
        t.expectTrue(false, "decoded foreground should have components")
    }

    // MARK: 0...1 clamping on decode

    // 8. Maximum hex (0xFF = 1.0) components should decode without crashing and stay <= 1.0.
    let maxHexJSON = buildJSON(v: 1, hex: "#FFFFFFFF")
    guard let maxDecoded = ThemeCodec.decode(maxHexJSON) else {
        t.expectTrue(false, "max hex should decode"); return
    }
    if let cs = maxDecoded.foregroundColor.components {
        for c in cs { t.expectTrue(Double(c) <= 1.0, "component <= 1.0") }
    }

    // MARK: SettingsStore customTheme round-trip

    // 9. Save and reload via UserDefaultsSettingsStore.
    let suite = "rubyfree.tests.codec.\(ProcessInfo.processInfo.processIdentifier)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        t.expectTrue(false, "could not create test suite"); return
    }
    defaults.removePersistentDomain(forName: suite)
    let store = UserDefaultsSettingsStore(defaults: defaults)

    // Fresh store: customTheme is nil.
    t.expectTrue(store.customTheme == nil, "fresh store has no custom theme")

    // Write preset.dark as custom and re-read.
    store.customTheme = preset
    let readBack = store.customTheme
    t.expectTrue(readBack != nil, "customTheme round-trips through UserDefaults")
    t.expectEqual(readBack?.id, "custom")

    // Setting nil removes the key.
    store.customTheme = nil
    t.expectTrue(store.customTheme == nil, "nil write removes customTheme")

    defaults.removePersistentDomain(forName: suite)
}

// MARK: - Helpers

/// Build a minimal ThemeDTO JSON with all five colour fields set to `hex` and version `v`.
private func buildJSON(v: Int, hex: String) -> String {
    let e = hex
    return "{\"v\":\(v),\"foreground\":\"\(e)\",\"ruby\":\"\(e)\",\"uncertain\":\"\(e)\",\"chipBackground\":\"\(e)\",\"chipStroke\":\"\(e)\"}"
}
