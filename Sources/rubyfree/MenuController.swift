import AppKit
import RubyfreeCore
import RubyfreeSystem

/// Owns the menu-bar `NSStatusItem` and its menu: an on/off toggle, live permission
/// status, "open System Settings" shortcuts when a grant is missing, and Quit.
///
/// The menu refreshes both on open (`menuNeedsUpdate`) and whenever the coordinator
/// reports a state change (`onStateChange`), so a permission lost while the menu is closed
/// still updates the status-item appearance.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {

    private let coordinator: AppCoordinator
    private let permissions: AXPermissionChecker
    private let statusItem: NSStatusItem
    private let useFake: Bool

    private let menu = NSMenu()
    private let toggleItem  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let axStatus    = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let axOpen      = NSMenuItem(title: "アクセシビリティを設定で開く…", action: nil, keyEquivalent: "")
    private let ocrStatus   = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let screenOpen  = NSMenuItem(title: "画面収録を設定で開く…", action: nil, keyEquivalent: "")
    private let themeItem   = NSMenuItem(title: "テーマ", action: nil, keyEquivalent: "")
    /// One radio item per preset, keyed by theme id, so `refresh()` can tick the active one.
    private var themeItems: [String: NSMenuItem] = [:]

    init(coordinator: AppCoordinator,
         permissions: AXPermissionChecker,
         statusItem: NSStatusItem,
         useFake: Bool) {
        self.coordinator = coordinator
        self.permissions = permissions
        self.statusItem = statusItem
        self.useFake = useFake
        super.init()
        build()
        coordinator.onStateChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func build() {
        toggleItem.target = self; toggleItem.action = #selector(toggleEnabled)
        axOpen.target = self;     axOpen.action = #selector(openAXSettings)
        screenOpen.target = self; screenOpen.action = #selector(openScreenSettings)
        axStatus.isEnabled = false
        ocrStatus.isEnabled = false

        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(axStatus)
        menu.addItem(axOpen)
        if !useFake {
            menu.addItem(ocrStatus)
            menu.addItem(screenOpen)
        } else {
            let f = NSMenuItem(title: "（FAKE_CAPTURE モード）", action: nil, keyEquivalent: "")
            f.isEnabled = false
            menu.addItem(f)
        }
        menu.addItem(.separator())
        buildThemeSubmenu()
        menu.addItem(themeItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "rubyfree を終了",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        menu.delegate = self
        statusItem.button?.title = "る"
        statusItem.menu = menu
    }

    /// Build the "テーマ" submenu: one radio item per ``RubyTheme`` preset. Selecting an item
    /// drives `coordinator.setTheme(id:)`; the active one is ticked in `refresh()`.
    private func buildThemeSubmenu() {
        let submenu = NSMenu()
        for preset in RubyTheme.allPresets {
            let item = NSMenuItem(title: preset.name,
                                  action: #selector(selectTheme(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = preset.id
            submenu.addItem(item)
            themeItems[preset.id] = item
        }
        themeItem.submenu = submenu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) { refresh() }

    // MARK: - Refresh

    func refresh() {
        let enabled = coordinator.isEnabled
        let p = coordinator.currentPermissions()

        toggleItem.title = enabled ? "ふりがな表示: オン" : "ふりがな表示: オフ"
        toggleItem.state = enabled ? .on : .off

        axStatus.title = p.accessibility ? "アクセシビリティ: 許可済み ✓"
                                         : "アクセシビリティ: 未許可 ✗（ふりがな不可）"
        axOpen.isHidden = p.accessibility

        if !useFake {
            ocrStatus.title = p.screenRecording
                ? "OCRフォールバック: 有効 ✓"
                : "OCRフォールバック: 画面収録の許可が必要（許可後に再起動）"
            screenOpen.isHidden = p.screenRecording
        }

        // Tick the active theme's radio item.
        let activeThemeID = coordinator.currentThemeID
        for (id, item) in themeItems {
            item.state = (id == activeThemeID) ? .on : .off
        }

        // Dim the menu-bar glyph when turned off, as a passive on/off cue.
        statusItem.button?.appearsDisabled = !enabled
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        coordinator.setEnabled(!coordinator.isEnabled)
        refresh()
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        coordinator.setTheme(id: id)
        refresh()
    }

    @objc private func openAXSettings() { permissions.openAccessibilitySettings() }
    @objc private func openScreenSettings() { permissions.openScreenRecordingSettings() }
}
