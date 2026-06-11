// rubyfree — menu-bar agent executable (composition root entry point).
//
// Wires the hover→capture→analyze→compose→overlay pipeline. Set RUBYFREE_FAKE_CAPTURE
// to exercise the whole pipeline without Accessibility (FakeTextCapture returns fixed
// text), which is how the state machine / overlay are tested without granting permissions.
// The full menu-bar UX and permission flow land in M4.

import AppKit
import RubyfreeCore
import RubyfreeSystem

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // agent app: no Dock icon

let permissions = AXPermissionChecker()
permissions.requestAccessibility()

let useFake = ProcessInfo.processInfo.environment["RUBYFREE_FAKE_CAPTURE"] != nil

// OCR fallback handles apps where AX cannot localize the word under the cursor
// (NSTextView/TextEdit, WebKit, PDFs). It needs Screen Recording; request it (JIT) and
// enable the fallback only once granted — a fresh grant takes effect on next launch.
// Prefer the bundled JMdict/kanjidic2 dictionary for accurate, multi-candidate readings.
// Overlay the user's registered readings (explicit settings values — never captured text)
// so a corrected/added reading wins. The merged dictionary is shared with both capture
// paths so a kanji run can be extended over okurigana (宛 → 宛も) and the analyzer resolves
// readings consistently. (Runtime re-merge after an in-app edit lands with the editor UI.)
let userDictionary = UserDictionaryStore()
let bundledDictionary = ReadingDictionary.bundled()
let effectiveDictionary = bundledDictionary?.merging(words: userDictionary.load())

let ocrCapture = OCRTextCapture(dictionary: effectiveDictionary)
let screenRecordingGranted = permissions.current().screenRecording
if !useFake && !screenRecordingGranted {
    permissions.requestScreenRecording()
}
let ocrEnabled = !useFake && screenRecordingGranted
if ocrEnabled {
    Task { await ocrCapture.prewarm() }
}

let capture: any TextCapturing = useFake
    ? FakeTextCapture()
    : TextCaptureStrategy(primary: AXTextCapture(dictionary: effectiveDictionary),
                          fallback: ocrEnabled ? ocrCapture : nil)
let secureDetector: any SecureFieldDetecting = useFake ? NoSecureFieldDetector() : AXSecureFieldDetector()

// Fall back to the CFStringTokenizer-based analyzer only if the dictionary resource is
// missing.
let analyzer: any JapaneseAnalyzing = effectiveDictionary.map { DictionaryAnalyzer(dictionary: $0) } ?? StandardAnalyzer()
if let effectiveDictionary {
    DebugLog.log("analyzer=DictionaryAnalyzer words=\(effectiveDictionary.words.count) kanji=\(effectiveDictionary.kanji.count) userEntries=\(userDictionary.count)")
} else {
    DebugLog.log("analyzer=StandardAnalyzer (bundled dictionary not found — degraded accuracy)")
}

let settings = UserDefaultsSettingsStore()

let coordinator = AppCoordinator(
    monitor: PollingMouseMonitor(),
    capture: capture,
    secureDetector: secureDetector,
    analyzer: analyzer,
    overlay: OverlayWindowController(),
    permissions: permissions,
    settings: settings
)
coordinator.start()

// Menu-bar UI: on/off toggle, live permission status, open-settings shortcuts, quit.
// Held for the process lifetime so its target/actions stay valid.
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let menuController = MenuController(
    coordinator: coordinator,
    permissions: permissions,
    statusItem: statusItem,
    useFake: useFake
)
_ = menuController  // keep alive

app.run()
