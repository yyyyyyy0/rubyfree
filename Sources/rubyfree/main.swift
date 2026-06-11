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
let ocrCapture = OCRTextCapture()
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
    : TextCaptureStrategy(primary: AXTextCapture(), fallback: ocrEnabled ? ocrCapture : nil)
let secureDetector: any SecureFieldDetecting = useFake ? NoSecureFieldDetector() : AXSecureFieldDetector()

// Prefer the bundled JMdict/kanjidic2 dictionary for accurate, multi-candidate readings;
// fall back to the CFStringTokenizer-based analyzer only if the resource is missing.
let bundledDictionary = ReadingDictionary.bundled()
let analyzer: any JapaneseAnalyzing = bundledDictionary.map { DictionaryAnalyzer(dictionary: $0) } ?? StandardAnalyzer()
if let bundledDictionary {
    DebugLog.log("analyzer=DictionaryAnalyzer words=\(bundledDictionary.words.count) kanji=\(bundledDictionary.kanji.count)")
} else {
    DebugLog.log("analyzer=StandardAnalyzer (bundled dictionary not found — degraded accuracy)")
}

let coordinator = AppCoordinator(
    monitor: PollingMouseMonitor(),
    capture: capture,
    secureDetector: secureDetector,
    analyzer: analyzer,
    overlay: OverlayWindowController(),
    permissions: permissions
)
coordinator.start()

// Minimal status item (full menu in M4).
let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "る"

let menu = NSMenu()
let axStatus = NSMenuItem(
    title: permissions.current().accessibility ? "アクセシビリティ: 許可済み ✓" : "アクセシビリティ: 未許可 ✗",
    action: nil, keyEquivalent: ""
)
axStatus.isEnabled = false
menu.addItem(axStatus)
if !useFake {
    let ocrLabel: String
    if ocrEnabled {
        ocrLabel = "OCR フォールバック: 有効 ✓"
    } else if screenRecordingGranted {
        ocrLabel = "OCR フォールバック: 無効"
    } else {
        ocrLabel = "OCR フォールバック: 画面収録の許可が必要（許可後に再起動）"
    }
    let ocrStatus = NSMenuItem(title: ocrLabel, action: nil, keyEquivalent: "")
    ocrStatus.isEnabled = false
    menu.addItem(ocrStatus)
}
if useFake {
    let fake = NSMenuItem(title: "（FAKE_CAPTURE モード）", action: nil, keyEquivalent: "")
    fake.isEnabled = false
    menu.addItem(fake)
}
menu.addItem(.separator())
menu.addItem(
    withTitle: "Quit rubyfree",
    action: #selector(NSApplication.terminate(_:)),
    keyEquivalent: "q"
)
statusItem.menu = menu

app.run()
