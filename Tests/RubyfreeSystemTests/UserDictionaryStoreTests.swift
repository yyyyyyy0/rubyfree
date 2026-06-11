import Foundation
import RubyfreeSystem
import TinyTest

func testUserDictionaryStore(_ t: TinyTest) {
    // Isolated temp file so the test never touches the real user dictionary.
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("rubyfree-tests-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    let fileURL = dir.appendingPathComponent("user-dict.tsv")
    try? FileManager.default.removeItem(at: dir)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = UserDictionaryStore(fileURL: fileURL)

    // 1. Empty/missing file → empty map.
    t.expectEqual(store.load().count, 0)

    // 2. add persists and round-trips through a fresh instance (relaunch).
    try? store.add(surface: "鬼灯", readings: ["ほおずき"])
    let reopened = UserDictionaryStore(fileURL: fileURL)
    t.expectEqual(reopened.load()["鬼灯"] ?? [], ["ほおずき"])
    t.expectEqual(reopened.count, 1)

    // 3. Katakana readings are normalised to hiragana; duplicates dropped.
    try? store.add(surface: "卍", readings: ["マンジ", "まんじ"])
    t.expectEqual(store.load()["卍"] ?? [], ["まんじ"])   // katakana→hiragana + dedupe

    // 4. remove deletes the entry.
    store.remove(surface: "卍")
    t.expectTrue(store.load()["卍"] == nil, "removed entry is gone")

    // 5. Invalid input throws (does not persist).
    var threwEmpty = false
    do { try store.add(surface: "   ", readings: ["x"]) } catch { threwEmpty = true }
    t.expectTrue(threwEmpty, "empty surface throws")

    var threwNoReading = false
    do { try store.add(surface: "海", readings: ["", "  "]) } catch { threwNoReading = true }
    t.expectTrue(threwNoReading, "no valid readings throws")

    var threwLongSurface = false
    do { try store.add(surface: String(repeating: "山", count: 17), readings: ["やま"]) }
    catch { threwLongSurface = true }
    t.expectTrue(threwLongSurface, "surface over 16 chars throws")

    var threwTab = false
    do { try store.add(surface: "a\tb", readings: ["x"]) } catch { threwTab = true }
    t.expectTrue(threwTab, "surface with control char throws")

    // 6. A reading containing the TSV delimiter ',' is dropped (not persisted as one field).
    try? store.add(surface: "西東", readings: ["に,し", "にし"])
    t.expectEqual(store.load()["西東"] ?? [], ["にし"])   // comma-bearing reading dropped

    // 7. Surviving entries are unaffected by the failed adds.
    t.expectEqual(store.load()["鬼灯"] ?? [], ["ほおずき"])

    // 8. load() re-applies bounds to a hand-edited/tampered file (fail-safe symmetry):
    //    an over-long surface line is dropped; a valid line survives.
    let longSurface = String(repeating: "永", count: 20)
    let tampered = "\(longSurface)\tよ\n正気\tしょうき\n"
    try? Data(tampered.utf8).write(to: fileURL, options: .atomic)
    let reloaded = UserDictionaryStore(fileURL: fileURL).load()
    t.expectTrue(reloaded[longSurface] == nil, "over-long surface dropped on load")
    t.expectEqual(reloaded["正気"] ?? [], ["しょうき"])
}
