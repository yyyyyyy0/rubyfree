// rubyfree — menu-bar agent executable (composition root).
//
// M1 skeleton: brings up an LSUIElement agent with a status item and requests
// Accessibility, so signing / TCC-subject stability can be validated end to end
// (this is the harness the S0-1 spike runs against). Full wiring (HoverReducer →
// AppState → TextCaptureStrategy → overlay) lands in M3/M4.

import AppKit
import ApplicationServices

let app = NSApplication.shared
// Agent app: no Dock icon, no app menu (mirrors LSUIElement in the .app bundle).
app.setActivationPolicy(.accessory)

// Request Accessibility (prompts on first run). Required for AX text capture and
// the basis of S0-1 (does the TCC grant survive a rebuild?).
// Use the literal key value: the SDK's `kAXTrustedCheckOptionPrompt` global is not
// concurrency-safe under Swift 6, and the constant's value is a stable public API string.
let axTrusted = AXIsProcessTrustedWithOptions(
    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
)

#if DEBUG
// Status/diagnostic only — never log captured user text (see PRIVACY.md / dev rules).
NSLog("rubyfree skeleton launched; accessibility trusted=\(axTrusted)")
#endif

let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "る"

let menu = NSMenu()
menu.addItem(
    withTitle: "Quit rubyfree",
    action: #selector(NSApplication.terminate(_:)),
    keyEquivalent: "q"
)
statusItem.menu = menu

app.run()
