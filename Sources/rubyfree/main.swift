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
let capture: any TextCapturing = useFake ? FakeTextCapture() : AXTextCapture()
let secureDetector: any SecureFieldDetecting = useFake ? NoSecureFieldDetector() : AXSecureFieldDetector()

let coordinator = AppCoordinator(
    monitor: PollingMouseMonitor(),
    capture: capture,
    secureDetector: secureDetector,
    analyzer: StandardAnalyzer(),
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
