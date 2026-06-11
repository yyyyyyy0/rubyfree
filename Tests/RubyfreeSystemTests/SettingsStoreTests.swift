import Foundation
import RubyfreeSystem
import TinyTest

func testSettingsStore(_ t: TinyTest) {
    // Use an isolated UserDefaults suite so the test never touches real preferences.
    let suite = "rubyfree.tests.\(ProcessInfo.processInfo.processIdentifier)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        t.expectTrue(false, "could not create test UserDefaults suite")
        return
    }
    defaults.removePersistentDomain(forName: suite)

    // 1. Default is enabled (fresh install should just work).
    let store = UserDefaultsSettingsStore(defaults: defaults)
    t.expectTrue(store.isEnabled, "absent key defaults to enabled")

    // 2. Writing persists and round-trips through a fresh instance (relaunch simulation).
    store.isEnabled = false
    t.expectTrue(store.isEnabled == false, "write is readable on same instance")
    let reopened = UserDefaultsSettingsStore(defaults: defaults)
    t.expectTrue(reopened.isEnabled == false, "preference survives a new store instance")

    // 3. Toggling back on persists too.
    reopened.isEnabled = true
    let again = UserDefaultsSettingsStore(defaults: defaults)
    t.expectTrue(again.isEnabled, "re-enabled preference persists")

    defaults.removePersistentDomain(forName: suite)
}
